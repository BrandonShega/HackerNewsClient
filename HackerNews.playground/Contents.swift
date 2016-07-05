//: Playground - noun: a place where people can play

import UIKit
import XCPlayground

XCPlaygroundPage.currentPage.needsIndefiniteExecution = true

typealias JSONDict = [String:AnyObject]

/*
 * RESOURCE
 */
struct Resource<T> {
    let url: NSURL
    let parse: NSData -> T?
}

extension Resource {
    init(url: NSURL, parseJSON: AnyObject -> T?) {
        self.url = url
        self.parse = { data in
            let json = try? NSJSONSerialization.JSONObjectWithData(data, options: [])
            return json.flatMap(parseJSON)
        }
    }
}

/*
 * STORY
 */
struct Story {
    var index: Int
    let by: String
    let numComments: Int
    let id: Int
    let score: Int
    let postedAt: Int
    let title: String
    let link: NSURL?
    
    var displayURL: String? {
        get {
            return nil
        }
    }
    
    var timeAgoString: String {
        get {
            return ""
        }
    }
}

extension Story {
    
    init?(dictionary: JSONDict) {
        guard let by = dictionary["by"] as? String,
            id = dictionary["id"] as? Int,
            score = dictionary["score"] as? Int,
            postedAt = dictionary["time"] as? Int,
            title = dictionary["title"] as? String,
            linkString = dictionary["url"] as? String,
            kids = dictionary["kids"] as? [Int] else { return nil }
        
        self.by = by
        self.id = id
        self.score = score
        self.postedAt = postedAt
        self.title = title
        self.link = NSURL(string: linkString)
        self.numComments = kids.count
        self.index = 0
    }
    
    init(id: Int) {
        self.id = id
        self.by = ""
        self.score = 0
        self.postedAt = 0
        self.title = ""
        self.link = nil
        self.numComments = 0
        self.index = 0
    }
    
    static let top = Resource<[Story]>(url: NSURL(string: "https://hacker-news.firebaseio.com/v0/topstories.json")!, parseJSON: { json in
        guard let storyIDs = json as? [Int] else { return nil }
        return storyIDs.flatMap(Story.init)
    })
    
    var info: Resource<Story> {
        let url = NSURL(string: "https://hacker-news.firebaseio.com/v0/item/\(id).json")!
        let resource = Resource<Story>(url: url) { json in
            guard let dictionary = json as? JSONDict else { return nil}
            return Story.init(dictionary: dictionary)
        }
        return resource
    }
}

/*
 * WEBSERVICE
 */
final class WebService {
    func load<T>(resource: Resource<T>, completion: (T?) -> ()) {
        NSURLSession.sharedSession().dataTaskWithURL(resource.url) { data, _, _ in
            let result = data.flatMap(resource.parse)
            completion(result)
        }.resume()
    }
}

/*
 * MAINNAVIGATIONCONTROLLER
 */
class MainNavigationController: UINavigationController {
    
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        navigationBar.barTintColor = UIColor(red: 0.9882352941, green: 0.4, blue: 0.1294117647, alpha: 1)
        navigationBar.translucent = false
        navigationBar.titleTextAttributes = [NSForegroundColorAttributeName : UIColor.whiteColor()]
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

/*
 * TOPSTORIESVIEWCONTROLLER
 */
class TopStoriesViewController: UIViewController {
    
    let tableView: UITableView
    private var storyIds = [Story]()
    private var stories = [Story]()
    private var start = 0
    private var numberOfRecords = 100
    
    init() {
        tableView = UITableView()
        super.init(nibName: nil, bundle: nil)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.redColor()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }
    
    func setup() {
        title = "Top Stories"
        view.backgroundColor = UIColor(hue: 60/360.0, saturation: 0.03, brightness: 0.96, alpha: 1)
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.registerClass(StoryCell.self, forCellReuseIdentifier: StoryCell.CellReuseIdentifier)
        tableView.estimatedRowHeight = 400
        tableView.rowHeight = UITableViewAutomaticDimension
        
        view.addSubview(tableView)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        tableView.leftAnchor.constraintEqualToAnchor(view.leftAnchor).active = true
        tableView.rightAnchor.constraintEqualToAnchor(view.rightAnchor).active = true
        tableView.topAnchor.constraintEqualToAnchor(view.topAnchor).active = true
        tableView.bottomAnchor.constraintEqualToAnchor(view.bottomAnchor).active = true
    }
    
    func refresh() {
        WebService().load(Story.top) { [weak self] result in
            guard let ids = result,
                weakSelf = self else { return }
            weakSelf.storyIds = ids
            let idsToLoad = weakSelf.storyIds[weakSelf.start...weakSelf.numberOfRecords]
            var count = 0
            for id in idsToLoad {
//            for id in weakSelf.storyIds {
                WebService().load(id.info) { [weak self] result in
                    guard let story = result,
                        weakSelf2 = self else { return }
                    dispatch_async(dispatch_get_main_queue(), {
                        weakSelf2.stories.append(story)
//                        weakSelf.tableView.beginUpdates()
                        let indexPath = NSIndexPath(forRow: count, inSection: 0)
                        weakSelf.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
//                        weakSelf.tableView.endUpdates()
                        count += 1
                    })
                }
            }
        }
    }
    
}

extension TopStoriesViewController: UITableViewDataSource {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stories.count
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithIdentifier(StoryCell.CellReuseIdentifier, forIndexPath: indexPath) as? StoryCell else { return UITableViewCell() }
        var story = stories[indexPath.row]
        story.index = indexPath.row + 1
        cell.configureWithStory(story)
        return cell
    }
}

extension TopStoriesViewController: UITableViewDelegate {
    
}

/*
 * STORYCELL
 */
class StoryCell: UITableViewCell {
    
    static let CellReuseIdentifier = "StoryCellReuseIdentifier"
    
    private var postedByLabel: UILabel
    private var websiteButton: UIButton
    private var titleLabel: UILabel
    private var bottomLabel: UILabel
    private var numberLabel: UILabel
    private var rightView: UIView
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        postedByLabel = UILabel()
        websiteButton = UIButton()
        titleLabel = UILabel()
        bottomLabel = UILabel()
        numberLabel = UILabel()
        rightView = UIView()
        
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        let innerViews: [UIView] = [postedByLabel, websiteButton, titleLabel, bottomLabel]
        let outerViews: [UIView] = [numberLabel, rightView]
        innerViews.forEach{rightView.addSubview($0)}
        outerViews.forEach{self.contentView.addSubview($0)}
        setUpViews()
        setUpConstraints()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureWithStory(story: Story) {
        postedByLabel.text = "Posted by \(story.by) "
        websiteButton.setTitle(story.displayURL, forState: .Normal)
        titleLabel.text = story.title
        bottomLabel.text = "\(story.score) points • \(story.numComments) comments • \(story.timeAgoString)"
        numberLabel.text = "\(story.index)"
        
        self.contentView.layoutIfNeeded()
    }
    
    func setUpViews() {
        backgroundColor = UIColor.clearColor()
        numberLabel.backgroundColor = UIColor(red:0.99, green:0.40, blue:0.13, alpha:1.00)
        numberLabel.textColor = UIColor.whiteColor()
        numberLabel.layer.cornerRadius = 2.0
        numberLabel.layer.masksToBounds = true
        numberLabel.textAlignment = .Center
        
        postedByLabel.font = UIFont.systemFontOfSize(12)
        postedByLabel.textColor = UIColor(red:0.72, green:0.74, blue:0.76, alpha:1.00)
        
        websiteButton.setTitleColor(UIColor(red:0.72, green:0.74, blue:0.76, alpha:1.00), forState: .Normal)
        websiteButton.titleLabel?.font = UIFont.systemFontOfSize(12)
//        websiteButton.addTarget(self, action: #selector(loadURL), for: .touchUpInside)
        
        titleLabel.numberOfLines = 0
        titleLabel.font = UIFont.boldSystemFontOfSize(15)
        
        bottomLabel.font = UIFont.systemFontOfSize(12)
        bottomLabel.textColor = UIColor(red:0.72, green:0.74, blue:0.76, alpha:1.00)
    }
    
    func setUpConstraints() {
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        rightView.translatesAutoresizingMaskIntoConstraints = false
        postedByLabel.translatesAutoresizingMaskIntoConstraints = false
        websiteButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomLabel.translatesAutoresizingMaskIntoConstraints = false
        
        numberLabel.widthAnchor.constraintEqualToConstant(30).active = true
        numberLabel.heightAnchor.constraintEqualToConstant(30).active = true
        numberLabel.leadingAnchor.constraintEqualToAnchor(contentView.leadingAnchor, constant: 20).active = true
        numberLabel.centerYAnchor.constraintEqualToAnchor(contentView.centerYAnchor, constant: 0).active = true
        
        rightView.leadingAnchor.constraintEqualToAnchor(numberLabel.trailingAnchor, constant: 20).active = true
        rightView.trailingAnchor.constraintEqualToAnchor(contentView.trailingAnchor, constant: -20).active = true
        rightView.topAnchor.constraintEqualToAnchor(contentView.topAnchor, constant: 0).active = true
        rightView.bottomAnchor.constraintEqualToAnchor(contentView.bottomAnchor, constant: 0).active = true
        
        postedByLabel.leadingAnchor.constraintEqualToAnchor(rightView.leadingAnchor, constant: 0).active = true
        postedByLabel.topAnchor.constraintEqualToAnchor(rightView.topAnchor, constant: 10).active = true
        postedByLabel.heightAnchor.constraintEqualToConstant(15)
        postedByLabel.setContentHuggingPriority(249, forAxis: .Vertical)
        
        websiteButton.leadingAnchor.constraintEqualToAnchor(postedByLabel.trailingAnchor, constant: 0).active = true
        websiteButton.topAnchor.constraintEqualToAnchor(rightView.topAnchor, constant: 0).active = true
        websiteButton.heightAnchor.constraintEqualToConstant(15).active = true
        
        titleLabel.leadingAnchor.constraintEqualToAnchor(rightView.leadingAnchor, constant: 0).active = true
        titleLabel.topAnchor.constraintEqualToAnchor(postedByLabel.topAnchor, constant: 20).active = true
        titleLabel.trailingAnchor.constraintEqualToAnchor(rightView.trailingAnchor, constant: 0).active = true
        titleLabel.heightAnchor.constraintGreaterThanOrEqualToConstant(15)
        titleLabel.setContentCompressionResistancePriority(251, forAxis: .Vertical)
        
        bottomLabel.leadingAnchor.constraintEqualToAnchor(rightView.leadingAnchor, constant: 0).active = true
        bottomLabel.topAnchor.constraintEqualToAnchor(titleLabel.bottomAnchor, constant: 5).active = true
        bottomLabel.bottomAnchor.constraintEqualToAnchor(rightView.bottomAnchor, constant: -10).active = true
        bottomLabel.setContentHuggingPriority(249, forAxis: .Vertical)
        bottomLabel.heightAnchor.constraintEqualToConstant(15)
    }
    
}

let topStoriesVC = TopStoriesViewController()
let navigationController = MainNavigationController(rootViewController: topStoriesVC)

XCPlaygroundPage.currentPage.liveView = navigationController
