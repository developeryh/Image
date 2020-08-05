//
//  ViewController.swift
//  ImagePractice
//
//  Created by YouHui on 2020/7/21.
//  Copyright © 2020 YouHui. All rights reserved.
//

import UIKit
import Kingfisher
import CoreGraphics
import ImageIO

extension Image {
    //优化： 向下采样
    public static func downsampleImage(at URL:NSURL, maxSize:Float) -> Image {
        let sourceOptions = [kCGImageSourceShouldCache:false] as CFDictionary
        let source = CGImageSourceCreateWithURL(URL as CFURL, sourceOptions)!
        let downsampleOptions = [kCGImageSourceCreateThumbnailFromImageAlways:true,     //是否创建缩略图
                                 kCGImageSourceThumbnailMaxPixelSize:maxSize,           //最大采样数
                                 kCGImageSourceShouldCacheImmediately:true,             //是否立即解码
                                 kCGImageSourceCreateThumbnailWithTransform:true,
                                 ] as CFDictionary
        let downsampledImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions)!
        return Image(cgImage: downsampledImage)
    }
    
    //优化：串行异步程解码 + 向下采样
    static let downsampleSerialQueue:DispatchQueue = DispatchQueue.init(label: "downsampleSerialQueue", qos: .default, attributes: [], autoreleaseFrequency: .workItem, target: nil)
    public static func asyncDownsampleImage(at URL:NSURL, maxSize:Float, complete:@escaping(Image)->()) {
        downsampleSerialQueue.async {
            let image = Image.downsampleImage(at: URL, maxSize: maxSize)
            DispatchQueue.main.async {
                complete(image)
            }
        }
    }
}

var imageDataKey = 100
extension ImageView :URLSessionDataDelegate {
    var imageData: Data {
        set {
            objc_setAssociatedObject(self, &imageDataKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            if let data = objc_getAssociatedObject(self, &imageDataKey) as? Data {
               return data
            }
            return Data.init()
        }
    }
    
    /// 下载图片
    /// - Parameter imageurl: 图片地址
    func downloadImageWithUrlStr(imageUrl : String, complete : @escaping (Bool)->()) {
        guard !imageUrl.isEmpty else {return}
        //编码特殊字符串
        let encodeUrl = imageUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        URLSession.shared.dataTask(with: URLRequest(url: URL(string: encodeUrl!)!), completionHandler: {
            (data, response, error) -> Void in
            if error != nil{
                print(error.debugDescription)
            } else {
                //将图片数据赋予UIImage
                let img = UIImage(data:data!)
                
                // 这里需要改UI，需要回到主线程
                DispatchQueue.main.async {
                    self.image = img
                    complete(true)
                }
            }
        }).resume()
    }
    
    /// 下载图片 （实时，大图时才有）
    /// - Parameter imageUrl: imageUrl
    func downloadImageActualTime(imageUrl: String) {
        guard !imageUrl.isEmpty else {return}
        //编码特殊字符串
        let encodeUrl = imageUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        let configuration = URLSessionConfiguration.default
        let currentSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
        currentSession.dataTask(with:  URLRequest(url: URL.init(string: encodeUrl!)!)).resume()
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        //拼接数据
        self.imageData.append(data)
        
        //是否完整的图片数据
        let finished = (self.imageData.count == dataTask.countOfBytesExpectedToReceive)
        
        //创建空图片空间
        let emptySpace = CGImageSourceCreateIncremental(nil);

        //更新图片空间数据
        CGImageSourceUpdateData(emptySpace, self.imageData as CFData, finished);

        //绘制图片（不会执行解码）
        let imageRef = CGImageSourceCreateImageAtIndex(emptySpace, 0, nil);

        //CGImageRef -> UIImage
        let image = UIImage.init(cgImage: imageRef!, scale: 1.0, orientation: .up)

        //显示图片
        DispatchQueue.main.async {
            self.image = image;
        }
    }
}

class ViewController: UIViewController {
    var image:UIImage?
    var imageView:UIImageView?
    lazy var tableView: ImageTableView = {
        let tableview = ImageTableView.init(frame: UIScreen.main.bounds, style: .plain)
        tableview.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell")
        return tableview
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(self.tableView)
    
//        self.imageView = UIImageView.init()
//        self.imageView?.backgroundColor = UIColor.red
//        self.imageView?.frame = CGRect.init(x: 0, y: 0, width:UIScreen.main.bounds.size.width, height: 200)
        //加载网络图片
//        self.imageView?.downloadImageWithUrlStr(imageurl: "http://pic.sc.chinaz.com/files/pic/pic9/201311/apic2117.jpg")
        
//        self.imageView?.downloadImageActualTime(imageUrl: "http://pic.jj20.com/up/allimg/811/011Q5132242/15011Q32242-2.jpg")
        
//        showImage(contentMode: .scaleAspectFit)
//
//        //通过名字加载本地图片
//        loadNameImage()

        //把图片试图加入到当前的view
//        self.view.addSubview(self.imageView!)
        // Do any additional setup after loading the view.
    }
    
    func loadContentImg() {
        let path = Bundle.main.path(forResource: "11", ofType: "jpg")
        self.image = UIImage.init(contentsOfFile: path!)
        self.imageView?.image = self.image
    }
    
    func loadNameImage() {
        self.image = UIImage.init(named: "07")
        self.imageView?.image = self.image
    }
    
    /*
     case scaleToFill ： 图片变形去匹配imageview （默认）
     case scaleAspectFit : 图片保持真实比例，从视图中心点扩张，直到任意一边到imageview 的边界
     case scaleAspectFill : 图片保持真实比例，从视图中心点扩张，直到全部边到imageview 的边界（可能有些图片或冲破imageview 的边界）
     */
    func showImage(contentMode:UIView.ContentMode) {
        self.imageView?.contentMode = contentMode
    }
}


class ImageTableView: UITableView, UITableViewDelegate, UITableViewDataSource {
    var imageArray:[String]?//图片地址
    var imageCacheDict:[String:Image]?//缓存图片
    override init(frame: CGRect, style: UITableView.Style) {
        self.imageCacheDict = [String:Image]()
        self.imageArray = [
            "http://pic.sc.chinaz.com/files/pic/pic9/201311/apic2117.jpg",
            "http://pic.jj20.com/up/allimg/811/011Q5132242/15011Q32242-2.jpg",
           "https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1596630044620&di=d8bb8bb84e87e7e96ca415877b30f7e6&imgtype=0&src=http%3A%2F%2Fa3.att.hudong.com%2F14%2F75%2F01300000164186121366756803686.jpg",
           "https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1596630044620&di=31099ac943f2f3d9e8abe5ba655d2771&imgtype=0&src=http%3A%2F%2Fa0.att.hudong.com%2F56%2F12%2F01300000164151121576126282411.jpg",
           "https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1596630044620&di=ae4619dfe179952f065b568c1ca0c313&imgtype=0&src=http%3A%2F%2Fa2.att.hudong.com%2F36%2F48%2F19300001357258133412489354717.jpg",
           "https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1596630044620&di=d62774ebbdcff60186fb8c055837be7a&imgtype=0&src=http%3A%2F%2Fa1.att.hudong.com%2F05%2F00%2F01300000194285122188000535877.jpg",
           "https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1596630044619&di=6bf493aa58160476073a4f9a5a41b1de&imgtype=0&src=http%3A%2F%2Fp2.so.qhimgs1.com%2Ft01dfcbc38578dac4c2.jpg",
           "https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1596630044619&di=1840596b94fd1a3059ea1a24490823ba&imgtype=0&src=http%3A%2F%2Fa4.att.hudong.com%2F22%2F59%2F19300001325156131228593878903.jpg",
           "https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1596630044619&di=c41a88c2ee2bbf9b1372e2ab72b28823&imgtype=0&src=http%3A%2F%2Fa1.att.hudong.com%2F62%2F02%2F01300542526392139955025309984.jpg",
           "https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1596630044619&di=fbb992c4fff952bbe8a4ec0c3990308c&imgtype=0&src=http%3A%2F%2Fa4.att.hudong.com%2F52%2F52%2F01200000169026136208529565374.jpg",
           "https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1596630044618&di=82b84ca68f59367bf95b5d4a5e90627c&imgtype=0&src=http%3A%2F%2Fa0.att.hudong.com%2F16%2F12%2F01300535031999137270128786964.jpg",
           "https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1596630044618&di=fe1ad4d0520321d9f3f9231388db0c57&imgtype=0&src=http%3A%2F%2Fa.hiphotos.baidu.com%2Fzhidao%2Fpic%2Fitem%2Fcc11728b4710b912d81c7b33c3fdfc0393452219.jpg",
           "https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1596630044618&di=983c986b32a06e0b618c001863ae498f&imgtype=0&src=http%3A%2F%2Fa3.att.hudong.com%2F57%2F28%2F01300000921826141405283668131.jpg",
           "https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1596630044618&di=749b8ec6c9a9e9ad281aecd7d18c1c3e&imgtype=0&src=http%3A%2F%2Fa3.att.hudong.com%2F13%2F41%2F01300000201800122190411861466.jpg",
           "https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1596630044617&di=a46c9cfc82b53272300bbd9faa2a7c3c&imgtype=0&src=http%3A%2F%2Fb-ssl.duitang.com%2Fuploads%2Fitem%2F201504%2F04%2F20150404H5058_kaZrB.jpeg",
           "https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1596630044617&di=42d9ee212791ba852cd691758d3050cb&imgtype=0&src=http%3A%2F%2Ffile02.16sucai.com%2Fd%2Ffile%2F2014%2F0829%2F372edfeb74c3119b666237bd4af92be5.jpg",
           "https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1596630044617&di=d35e580250f11adf0aa1c1953cc782c7&imgtype=0&src=http%3A%2F%2Ffile.digitaling.com%2FeImg%2Fuimages%2F20150824%2F1440412608821067.jpg",
           "https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1596630044616&di=781f78ada7564969ec0a8505e974f268&imgtype=0&src=http%3A%2F%2Fa3.att.hudong.com%2F55%2F22%2F20300000929429130630222900050.jpg",
        ]
        super.init(frame: frame, style: style)
        self.delegate = self
        self.dataSource = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return imageArray!.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell")
        
        //是否存在缓存的图片
        let imageUrlStr = self.imageArray![indexPath.row]
        if (self.imageCacheDict?[imageUrlStr] == nil) {
            //填充一个空的数据，防止在下载途中多次下载
            self.imageCacheDict?[imageUrlStr] = Image.init()
            Image.asyncDownsampleImage(at: URL.init(string: imageUrlStr)! as NSURL, maxSize: 100) { (image) in
                cell?.imageView?.image = image
                cell?.imageView?.contentMode = .scaleAspectFit
                self.imageCacheDict?[imageUrlStr] = image
            }
        }
   
//        let resouce:Resource = URL.init(string: imageArray![indexPath.row])!
//        cell?.imageView?.kf.setImage(with: resouce)
//        cell?.imageView?.downloadImageActualTime(imageUrl: self.imageArray?[indexPath.row] ?? "")
        return cell!
    }
}




