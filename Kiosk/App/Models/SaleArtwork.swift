import UIKit

public enum ReserveStatus: String {
    case ReserveNotMet = "reserve_not_met"
    case NoReserve = "no_reserve"
    case ReserveMet = "reserve_met"

    public var reserveNotMet: Bool {
        return self == .ReserveNotMet
    }

    public static func initOrDefault (rawValue: String?) -> ReserveStatus {
        return ReserveStatus(rawValue: rawValue ?? "") ?? .NoReserve
    }
}

struct SaleNumberFormatter {
    static let dollarFormatter = createDollarFormatter()
}

private let kNoBidsString = "0 bids placed"

class SaleArtwork: JSONAble {

    let id: String
    let artwork: Artwork

    var auctionID: String?

    // The bidder is given from JSON if user is registered
    let bidder: Bidder?

    var saleHighestBid: Bid?
    dynamic var bidCount:  NSNumber?

    var userBidderPosition: BidderPosition?
    var positions: [String]?

    dynamic var openingBidCents: NSNumber?
    dynamic var minimumNextBidCents: NSNumber?

    dynamic var highestBidCents: NSNumber?
    var lowEstimateCents: Int?
    var highEstimateCents: Int?

    dynamic var reserveStatus: String?


    init(id: String, artwork: Artwork) {
        self.id = id
        self.artwork = artwork
    }

    override class func fromJSON(json: [String: AnyObject]) -> JSONAble {
        let json = JSON(json)
        let id = json["id"].stringValue
        let artworkDict = json["artwork"].object as [String: AnyObject]
        let artwork = Artwork.fromJSON(artworkDict) as Artwork

        let saleArtwork = SaleArtwork(id: id, artwork: artwork) as SaleArtwork

        if let highestBidDict = json["highest_bid"].object as? [String: AnyObject] {
            saleArtwork.saleHighestBid = Bid.fromJSON(highestBidDict) as? Bid
        }

        saleArtwork.auctionID = json["sale_id"].string
        saleArtwork.openingBidCents = json["opening_bid_cents"].int
        saleArtwork.minimumNextBidCents = json["minimum_next_bid_cents"].int

        saleArtwork.highestBidCents = json["highest_bid_amount_cents"].int
        saleArtwork.lowEstimateCents = json["low_estimate_cents"].int
        saleArtwork.highEstimateCents = json["high_estimate_cents"].int
        saleArtwork.bidCount = json["bidder_positions_count"].int
        saleArtwork.reserveStatus = json["reserve_status"].string

        return saleArtwork;
    }
    
    func updateWithValues(newSaleArtwork: SaleArtwork) {
        saleHighestBid = newSaleArtwork.saleHighestBid
        auctionID = newSaleArtwork.auctionID
        openingBidCents = newSaleArtwork.openingBidCents
        minimumNextBidCents = newSaleArtwork.minimumNextBidCents
        highestBidCents = newSaleArtwork.highestBidCents
        lowEstimateCents = newSaleArtwork.lowEstimateCents
        highEstimateCents = newSaleArtwork.highEstimateCents
        bidCount = newSaleArtwork.bidCount
    }
    
    var estimateString: String {
        switch (lowEstimateCents, highEstimateCents) {
        case let (.Some(lowCents), .Some(highCents)):
            let lowDollars = NSNumberFormatter.currencyStringForCents(lowCents)
            let highDollars = NSNumberFormatter.currencyStringForCents(highCents)
            return "Estimate: \(lowDollars)–\(highDollars)"
        case let (.Some(lowCents), nil):
            let lowDollars = NSNumberFormatter.currencyStringForCents(lowCents)
            return "Estimate: \(lowDollars)"
        case let (nil, .Some(highCents)):
            let highDollars = NSNumberFormatter.currencyStringForCents(highCents)
            return "Estimate: \(highDollars)"
        default:
            return "No Estimate"
        }
    }

    var numberOfBidsSignal: RACSignal {
        return RACObserve(self, "bidCount").map { (optionalBidCount) -> AnyObject! in
            // Technically, the bidCount is Int?, but the `as?` cast could fail (it never will, but the compiler doesn't know that)
            // So we need to unwrap it as an optional optional. Yo dawg.
            let bidCount = optionalBidCount as Int?

            if let bidCount = bidCount {
                let suffix = bidCount == 1 ? "" : "s"
                return "\(bidCount) bid\(suffix) placed"
            } else {
                return kNoBidsString
            }
        }
    }

    // The language used here is very specific – see https://github.com/artsy/eidolon/pull/325#issuecomment-64121996 for details
    var numberOfBidsWithReserveSignal: RACSignal {
        return RACSignal.combineLatest([numberOfBidsSignal, RACObserve(self, "reserveStatus")]).map { (object) -> AnyObject! in
            let tuple = object as RACTuple
            let numberOfBidsString = tuple.first as String
            let reserveStatus = ReserveStatus.initOrDefault(tuple.second as? String)

            // if there is no reserve, just return the number of bids string.
            if reserveStatus == .NoReserve {
                return numberOfBidsString
            } else {
                if numberOfBidsString == kNoBidsString {
                    // If there are no bids, then return only this string.
                    return "This lot has a reserve"
                } else if reserveStatus == .ReserveNotMet {
                    return "(\(numberOfBidsString), Reserve not met)"
                } else { // implicitly, reserveStatus is .ReserveMet
                    return "(\(numberOfBidsString), Reserve met)"
                }
            }
        }
    }

    func currentBidSignal(prefix: String = "", missingPrefix: String = "") -> RACSignal {
        return RACObserve(self, "highestBidCents").map({ [weak self] (highestBidCents) -> AnyObject! in
            if let currentBidCents = highestBidCents as? Int {
                return "\(prefix)\(NSNumberFormatter.currencyStringForCents(currentBidCents))"
            } else {
                return "\(missingPrefix)\(NSNumberFormatter.currencyStringForCents(self?.openingBidCents ?? 0))"
            }
        })
    }

    override class func keyPathsForValuesAffectingValueForKey(key: String) -> NSSet {
        if key == "estimateString" {
            return NSSet(array: ["lowEstimateCents", "highEstimateCents"])
        } else {
            return super.keyPathsForValuesAffectingValueForKey(key)
        }
    }
}

func createDollarFormatter() -> NSNumberFormatter {
    let formatter = NSNumberFormatter()
    formatter.numberStyle = NSNumberFormatterStyle.CurrencyStyle

    // This is always dollars, so let's make sure that's how it shows up
    // regardless of locale.

    formatter.currencyGroupingSeparator = ","
    formatter.currencySymbol = "$"
    formatter.maximumFractionDigits = 0
    return formatter
}
