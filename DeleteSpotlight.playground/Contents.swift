import Cocoa
import CoreSpotlight


var waiting = true

func getSpotlightEntries (queryString: String) -> Int {
//    let queryString = "title==*"
    let query = CSSearchQuery(queryString : queryString,
                          attributes : ["title"])
    var nSpotlightEntries = 0
    var completed = false
    query.completionHandler = { (error) -> Void in
        if error != nil {
            switch error!._domain {
            case CSSearchQueryErrorDomain:
                print(error.debugDescription)
            default:
                break
            }
        }
        nSpotlightEntries = query.foundItemCount
        completed = true
    }
    query.start()
    while (completed == false){
        usleep(10000)
    }
    return nSpotlightEntries
}

func deleteSpotlightEntries () {
    
    CSSearchableIndex(name: "com.TeXHelp.TeXHelp").deleteAllSearchableItems(completionHandler: { (error) -> Void in
        if error != nil {
            print(error?.localizedDescription ?? "Error")
        }
        else {
                print("Deleted")
        }
        waiting = false
    })


    while waiting {
        
    }
}

getSpotlightEntries(queryString: "* == 'TeX Help: *'")
