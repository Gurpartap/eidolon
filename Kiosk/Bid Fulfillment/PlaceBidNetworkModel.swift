import UIKit
import ReactiveCocoa
import Moya

public class PlaceBidNetworkModel: NSObject {

    var fulfillmentNav:FulfillmentNavigationController!
    var bidderPosition:BidderPosition?

    public func bidSignal(bidDetails: BidDetails) -> RACSignal {

        let saleArtwork = bidDetails.saleArtwork
        let cents = String(bidDetails.bidAmountCents! as Int)
        return bidOnSaleArtwork(saleArtwork!, bidAmountCents: cents)
    }

    public func provider() -> ReactiveMoyaProvider<ArtsyAPI>  {
        if let provider = fulfillmentNav.loggedInProvider {
            return provider
        }
        return Provider.sharedProvider
    }

    private func bidOnSaleArtwork(saleArtwork: SaleArtwork, bidAmountCents: String) -> RACSignal {
        let bidEndpoint: ArtsyAPI = ArtsyAPI.PlaceABid(auctionID: saleArtwork.auctionID!, artworkID: saleArtwork.artwork.id, maxBidCents: bidAmountCents)

        let request = provider().request(bidEndpoint, method: .POST, parameters:bidEndpoint.defaultParameters).filterSuccessfulStatusCodes().mapJSON().mapToObject(BidderPosition.self)

        return request.doNext { [weak self] (position) -> Void in
            self?.bidderPosition = position as? BidderPosition
            return

        }.doError { (error) in
            logger.log("Bidding on Sale Artwork failed.")
            logger.log("Error: \(error.localizedDescription). \n \(error.artsyServerError())")
        }
    }

}
