import '../models/models.dart';

/// Mock 数据层（全新架构：所有数据集中管理，离线可用）
class MockData {
  MockData._();

  // ============================= 首页 =============================

  /// 轮播图
  static const List<String> bannerImages = [
    'https://aecpm.alicdn.com/simba/img/TB14ab1KpXXXXclXFXXSutbFXXX.jpg_q50.jpg',
    'https://gw.alicdn.com/imgextra/i4/34/O1CN01Wz3LuY1C7bzPXexNf_!!34-0-lubanu.jpg',
    'https://gw.alicdn.com/imgextra/i1/99/O1CN01MswjVp1CbNjd1qL0N_!!99-0-lubanu.jpg',
    'https://aecpm.alicdn.com/tfscom/TB1jDYURMHqK1RjSZFgXXa7JXXa.jpg_q50.jpg',
    'https://gw.alicdn.com/imgextra/i4/196/O1CN01GM2TCU1DJo9Q4paY5_!!196-0-lubanu.jpg',
    'https://gw.alicdn.com/imgextra/i1/101/O1CN012LEy4Q1CcIWfvJWbw_!!101-0-lubanu.jpg',
  ];

  /// 金刚区入口（20 个）
  static const List<KingKongItem> kingKongItems = [
    KingKongItem(
        title: '天猫',
        picUrl:
            'https://gw.alicdn.com/tfs/TB1Wxi2trsrBKNjSZFpXXcXhFXa-183-144.png_.webp'),
    KingKongItem(
        title: '聚划算',
        picUrl:
            'https://img.alicdn.com/tfs/TB10UHQaNjaK1RjSZKzXXXVwXXa-183-144.png?getAvatar=1_.webp'),
    KingKongItem(
        title: '天猫国际',
        picUrl:
            'https://gw.alicdn.com/tfs/TB11rTqtj7nBKNjSZLeXXbxCFXa-183-144.png?getAvatar=1_.webp'),
    KingKongItem(
        title: '外卖',
        picUrl:
            'https://gw.alicdn.com/tps/TB1eXc7PFXXXXb4XpXXXXXXXXXX-183-144.png?getAvatar=1_.webp'),
    KingKongItem(
        title: '天猫超市',
        picUrl:
            'https://gw.alicdn.com/tfs/TB1IKqDtpooBKNjSZFPXXXa2XXa-183-144.png_.webp'),
    KingKongItem(
        title: '充值中心',
        picUrl:
            'https://gw.alicdn.com/tfs/TB1o0FLtyMnBKNjSZFoXXbOSFXa-183-144.png_.webp'),
    KingKongItem(
        title: '飞猪旅行',
        picUrl:
            'https://gw.alicdn.com/tfs/TB15nKhtpkoBKNjSZFEXXbrEVXa-183-144.png?getAvatar=1_.webp'),
    KingKongItem(
        title: '领金币',
        picUrl:
            'https://gw.alicdn.com/tfs/TB1BqystrZnBKNjSZFrXXaRLFXa-183-144.png?getAvatar=1_.webp'),
    KingKongItem(
        title: '拍卖',
        picUrl:
            'https://gw.alicdn.com/tfs/TB1CMf4tlnTBKNjSZPfXXbf1XXa-183-144.png?getAvatar=1_.webp'),
    KingKongItem(
        title: '分类',
        picUrl:
            'https://gw.alicdn.com/tfs/TB18P98tyQnBKNjSZFmXXcApVXa-183-144.png?getAvatar=1_.webp'),
    KingKongItem(
        title: '方便速食',
        picUrl:
            'https://img.alicdn.com/tps/i4/TB1jlPASjTpK1RjSZKPwu13UpXa.png_170x120Q90s50.jpg_.webp'),
    KingKongItem(
        title: '休闲零食',
        picUrl:
            'https://img.alicdn.com/tps/i4/TB1kgvvSb2pK1RjSZFswu1NlXXa.png_170x120Q90s50.jpg_.webp'),
    KingKongItem(
        title: '奶品水饮',
        picUrl:
            'https://img.alicdn.com/tps/i4/TB1kRDxShTpK1RjSZFMwu2G_VXa.png_170x120Q90s50.jpg_.webp'),
    KingKongItem(
        title: '粮油米面',
        picUrl:
            'https://img.alicdn.com/tps/i4/TB1pBTpSgTqK1RjSZPhwu0fOFXa.png_170x120Q90s50.jpg_.webp'),
    KingKongItem(
        title: '厨房日用',
        picUrl:
            'https://img.alicdn.com/tps/i4/TB1tae9k_Zmx1VjSZFGwu1x2XXa.png_170x120Q90s50.jpg_.webp'),
    KingKongItem(
        title: '母婴用品',
        picUrl:
            'https://img.alicdn.com/tps/i4/TB1fv6CSXzqK1RjSZFCwu2bxVXa.png_170x120Q90s50.jpg_.webp'),
    KingKongItem(
        title: '个人护理',
        picUrl:
            'https://img.alicdn.com/tps/i4/TB1nIjsSmzqK1RjSZFLwu3n2XXa.png_170x120Q90s50.jpg_.webp'),
    KingKongItem(
        title: '家清家居',
        picUrl:
            'https://img.alicdn.com/tps/i4/TB14cv0ShjaK1RjSZKzwu0VwXXa.png_170x120Q90s50.jpg_.webp'),
    KingKongItem(
        title: '进口好货',
        picUrl:
            'https://img.alicdn.com/tps/i4/TB1hNvrSgDqK1RjSZSywu1xEVXa.png_170x120Q90s50.jpg_.webp'),
    KingKongItem(
        title: '新人包邮',
        picUrl:
            'https://img.alicdn.com/tps/i4/TB1lDbzSXzqK1RjSZFowu2fcXXa.png_170x120Q90s50.jpg_.webp'),
  ];

  /// 新品推荐卡片
  static const List<RecommendItem> recommendItems = [
    RecommendItem(
        title: '聚划算',
        subtitle: '抢100元卷',
        bgColor: '#fcf8f4',
        subtitleColor: '#fd4f51',
        picUrl:
            'https://img.alicdn.com/tfs/TB1rCjhUyLaK1RjSZFxXXamPFXa-345-345.png_400x400Q50s50.jpg_.webp'),
    RecommendItem(
        title: '',
        subtitle: '现金红包',
        bgColor: '#fcf8f4',
        subtitleColor: '#ff7525',
        picUrl:
            'https://img.alicdn.com/tfs/TB1Ekx_UwHqK1RjSZFkXXX.WFXa-345-297.png_400x400Q50s50.jpg_.webp'),
    RecommendItem(
        title: '淘宝直播',
        subtitle: '抢直播福利',
        subtitleColor: '#ff4d7c',
        picUrl:
            'https://img.alicdn.com/imgextra/i3/2459495011/TB28AUmDNGYBuNjy0FnXXX5lpXa_!!2459495011.png_400x400Q50s50.jpg_.webp'),
    RecommendItem(
        title: '',
        subtitle: '',
        picUrl:
            'https://img.alicdn.com/imgextra/i2/6000000006286/TB2y0_SGxGYBuNjy0FnXXX5lpXa_!!6000000006286-2-at.png_440x440Q50s50.jpg_.webp'),
    RecommendItem(
        title: '淘抢购',
        subtitle: '限时半价',
        bgColor: '#fcf8f4',
        subtitleColor: '#f8003d',
        picUrl:
            'https://img.alicdn.com/imgextra/i1/52660971/O1CN011J2l2EZDLLw1gsZ_!!52660971.png_400x400Q50s50.jpg_.webp'),
    RecommendItem(
        title: '天天特价',
        subtitle: '9.9包邮',
        bgColor: '#fcf8f4',
        subtitleColor: '#fd4e0e',
        picUrl:
            'https://img.alicdn.com/imgextra/i2/229042948/TB2f9PupqmWBuNjy1XaXXXCbXXa_!!229042948.png_400x400Q50s50.jpg_.webp'),
    RecommendItem(
        title: '有好货',
        subtitle: '发现世间好物',
        subtitleColor: '#56beff',
        picUrl:
            'https://img.alicdn.com/imgextra/i1/818931597/TB2POGYdQSWBuNjSszdXXbeSpXa_!!818931597.png_400x400Q50s50.jpg_.webp'),
    RecommendItem(
        title: '',
        subtitle: '',
        picUrl:
            'https://img.alicdn.com/imgextra/i1/1014281128/O1CN01x1KqZr1KCfHMTYfEB_!!1014281128.png_400x400Q50s50.jpg_.webp'),
    RecommendItem(
        title: '每日好店',
        subtitle: '挖深藏的店',
        subtitleColor: '#f8a507',
        picUrl:
            'https://img.alicdn.com/imgextra/i3/2695817590/O1CN01mJlWJA25wGcZYDdwk_!!2695817590.png_400x400Q50s50.jpg_.webp'),
    RecommendItem(
        title: '',
        subtitle: '',
        picUrl:
            'https://img.alicdn.com/imgextra/i1/420722466/O1CN011U5T9psOfc6QV8w_!!420722466.png_400x400Q50s50.jpg_.webp'),
    RecommendItem(
        title: '哇哦视频',
        subtitle: '抢初夏必买',
        subtitleColor: '#fe5f08',
        picUrl:
            'https://img.alicdn.com/imgextra/i3/2090142745/O1CN01dnOm5n1W9FiYxo7JT_!!2090142745.png_400x400Q50s50.jpg_.webp'),
    RecommendItem(
        title: '',
        subtitle: '',
        picUrl:
            'https://img.alicdn.com/imgextra/i4/619789678/TB2JWZrX9f8F1Jjy0FeXXallpXa_!!619789678.png_400x400Q50s50.jpg_.webp'),
  ];

  /// 顶部黑字热搜轮播（2-3秒自动切换，与搜索框占位同步）
  static const List<String> hotSearchProducts = [
    '摩可多黑条固体饮料',
    'OPPO Find X7 新品上市',
    '戴森吹风机 HD15',
    '兰蔻小黑瓶精华 50ml',
    '蒙牛纯牛奶 250ml*16盒',
    'Swisse 护肝片 100片',
    '立白大师香氛洗衣液 1kg',
    '华为 Mate 60 Pro',
    '小米空气净化器 4',
    '索尼 WH-1000XM5',
  ];

  /// 热搜词
  static const List<String> searchHints = [
    '显示器4k',
    '显示器4k 144hz',
    '显示器4k 曲面',
    '电脑显示器4k',
    '显示器4k二手',
    '显示器27英寸4k',
    'aoc4k显示器',
    '43寸4k显示器',
    '4k显示器 曲面屏',
    'lg4k显示器',
  ];

  /// 搜索历史（默认）
  static const List<String> searchRecords = [
    'aoc4k显示器',
    'lg4k显示器',
    '菠萝',
    'iphone xs',
    '华为 p30',
    '三星 手机',
    'macbook pro 2018',
    'dell xps15 9570',
  ];

  /// 头条滚动
  static const List<String> headlines = [
    'MT大白洗碗机测评：用了就再也回不去了',
    '我与MT大白洗碗机的蜗居生活',
    '太平洋电脑网每日早报，10月25日份，请查收',
    '新版手机淘宝上线！逛街时可以摇出红包！赶紧更新吧',
    '天猫双11手机&配件预售会场满减大促',
  ];

  /// 首页图标区 第 1 页（单行 5 个 + 第 6 个半露"红包签到"）
  static const List<HomeIconEntry> homeIconPage1 = [
    HomeIconEntry('天猫超市', '超市', 0xFF22c55e),
    HomeIconEntry('淘宝秒杀', '秒', 0xFFff2d2d),
    HomeIconEntry('领淘金币', '币', 0xFFf7b500),
    HomeIconEntry('88VIP', '88', 0xFF2b2b2b),
    HomeIconEntry('芭芭农场', '领', 0xFFff4d4f),
    HomeIconEntry('红包签到', '¥', 0xFFff3b30),
  ];

  /// 首页图标区 第 2 页（3 行 × 5 = 15 个）
  static const List<HomeIconEntry> homeIconPage2 = [
    HomeIconEntry('红包签到', '¥', 0xFFff3b30),
    HomeIconEntry('天猫新品', '新品', 0xFFa98548),
    HomeIconEntry('淘工厂', '厂', 0xFFff6a00),
    HomeIconEntry('活动日历', '历', 0xFFf43f5e),
    HomeIconEntry('淘宝礼物', '礼', 0xFFef4444),
    HomeIconEntry('淘鲜达', '鲜', 0xFF22c55e),
    HomeIconEntry('淘宝闪购', '购', 0xFFff7d00),
    HomeIconEntry('淘票票', '票', 0xFFff4d4f),
    HomeIconEntry('聚划算', '聚', 0xFFe11d74),
    HomeIconEntry('充值中心', '充', 0xFFff8c00),
    HomeIconEntry('飞猪旅行', '猪', 0xFFfbbf24),
    HomeIconEntry('分类', '三', 0xFF8b5cf6),
    HomeIconEntry('天猫国际', '际', 0xFF7c3aed),
    HomeIconEntry('资质规则', '✓', 0xFF3b82f6),
    HomeIconEntry('全部频道', '●', 0xFFf59e0b),
  ];

  /// 首页"淘宝直播/直播有好价/百亿补贴/国家补贴"四卡（固定不随图标滑动）
  static const List<HomeLiveCard> homeLiveCards = [
    HomeLiveCard(
        title: '淘宝直播',
        titleColor: 0xFF1a1a1a,
        imageUrl: 'assets/images/remote/r0040.jpg',
        priceText: '直播价¥32',
        priceColor: 0xFFff2d55),
    HomeLiveCard(
        title: '直播有好价',
        titleColor: 0xFFff2d55,
        imageUrl: 'assets/images/remote/r0042.jpg',
        priceText: '直播价¥4',
        priceColor: 0xFFff2d55),
    HomeLiveCard(
        title: '百亿补贴',
        titleColor: 0xFF1a1a1a,
        imageUrl: 'assets/images/remote/r0044.jpg',
        priceText: '补贴价¥47',
        priceColor: 0xFFff2d55),
    HomeLiveCard(
        title: '国家补贴',
        titleColor: 0xFF16a34a,
        imageUrl: 'assets/images/remote/r0047.jpg',
        priceText: '补贴价¥9.43',
        priceColor: 0xFFff2d55),
  ];

  /// 首页顶部 Tab
  static const List<HomeTab> homeTabs = [
    HomeTab(title: '猜你喜欢'),
    HomeTab(title: '直播'),
    HomeTab(title: '便宜好货'),
    HomeTab(title: '品牌闪购'),
  ];

  // ============================= 商品 =============================

  /// 猜你喜欢商品流（mock，保健品/食品，使用本地真实商品图）
  static const List<SearchResultItem> guessLikeGoods = [
    SearchResultItem(
        imageUrl: 'assets/images/remote/r0046.jpg',
        title: '立白大师香氛洗衣液 1kg 官方正品 持久留香',
        shopName: '立白官方旗舰店',
        price: '3.01',
        commentCount: '已售1万+',
        goodRate: '98%好评'),
    SearchResultItem(
        imageUrl: 'assets/images/remote/r0039.jpg',
        title: 'SAH Swiss Alp Health 瑞士胶原蛋白粉 1000mg 高含量 抗衰',
        shopName: 'SAH 海外旗舰店',
        price: '990.7',
        commentCount: '全网热销100+',
        goodRate: '97%好评'),
    SearchResultItem(
        imageUrl: 'assets/images/remote/r0045.jpg',
        title: '蒙牛纯牛奶 250ml*16盒 整箱装 早餐奶',
        shopName: '蒙牛官方旗舰店',
        price: '45',
        commentCount: '20万人付款',
        goodRate: '99%好评'),
    SearchResultItem(
        imageUrl: 'assets/images/remote/r0044.jpg',
        title: 'Swisse 护肝片 100片 澳洲进口 应酬必备',
        shopName: 'Swisse 海外旗舰店',
        price: '178',
        commentCount: '5万人付款',
        goodRate: '98%好评'),
    SearchResultItem(
        imageUrl: 'assets/images/remote/r0051.jpg',
        title: '太太乐鸡精 100g*10袋 家用调味 火锅炒菜',
        shopName: '太太乐官方旗舰店',
        price: '12.5',
        commentCount: '8万人付款',
        goodRate: '99%好评'),
    SearchResultItem(
        imageUrl: 'assets/images/remote/r0040.jpg',
        title: '江中健胃消食片 50片 儿童成人 健脾',
        shopName: '江中药业官方旗舰店',
        price: '18.5',
        commentCount: '3万人付款',
        goodRate: '97%好评'),
  ];

  // ============================= 购物车 =============================

  static List<ShoppingCartShop> get shoppingCartShops => [
        ShoppingCartShop(
          shopName: '华为官方旗舰店',
          shopType: ShopType.tianMao,
          hasTmallEasyBuy: true,
          discounts: '已满99元，享包邮',
          items: [
            OrderItem(
                imageUrl:
                    'https://img.alicdn.com/bao/uploaded/i5/TB1trAMNQPoK1RjSZKb.LB1IXXa_101123.jpg_80x80.jpg',
                title: '【旗舰新品 稀缺货源】Huawei/华为 P30全面屏超感光徕卡三摄变焦',
                configuration: '4G全网通;天空之境;官方标配;8+64GB',
                stock: 2,
                price: 3988),
            OrderItem(
                imageUrl:
                    'https://img.alicdn.com/bao/uploaded/i8/TB1uiAYNMHqK1RjSZFkXfd.WFXa_112352.jpg_80x80.jpg',
                title: '【旗舰新品 稀缺货源】Huawei/华为P30 Pro曲面屏超感光徕卡四摄变',
                configuration: '4G全网通;极光色;官方标配;8+512GB',
                stock: 1,
                price: 6788),
          ],
        ),
        ShoppingCartShop(
          shopName: '小米官方旗舰店',
          shopType: ShopType.tianMao,
          hasCoupons: true,
          discounts: '已满150包邮',
          items: [
            OrderItem(
                imageUrl:
                    'https://img.alicdn.com/bao/uploaded/i5/TB1d4D5HQzoK1RjSZFlDP9i4VXa_121840.jpg_80x80.jpg',
                title: '【现货速发】Xiaomi/小米9 骁龙855全面屏索尼4800万指纹拍照',
                configuration: '4G+全网通全息幻彩蓝官方标配6+128GB购机送',
                stock: 5,
                price: 2999),
            OrderItem(
                imageUrl:
                    'https://img.alicdn.com/bao/uploaded/i5/TB1d4D5HQzoK1RjSZFlDP9i4VXa_121840.jpg_80x80.jpg',
                title: '【现货速发】Xiaomi/小米9 骁龙855全面屏索尼4800万指纹拍照',
                configuration: '4G+全网通全息幻彩蓝官方标配8+128GB购机送',
                stock: 5,
                price: 3299),
          ],
        ),
        ShoppingCartShop(
          shopName: 'lg金捷专卖店',
          shopType: ShopType.tianMao,
          items: [
            OrderItem(
                imageUrl:
                    'https://img.alicdn.com/bao/uploaded/i1/2074230498/O1CN01lZnjxG1FY7lsf191X_!!0-item_pic.jpg_80x80.jpg',
                title: '【官方自营】LG 27UK650-W 27英寸10bit 电脑 IPS 4K显示器升降',
                configuration: '官方标配;白色',
                stock: 0,
                price: 3099),
          ],
        ),
        ShoppingCartShop(
          shopName: '趣玩黑市',
          shopType: ShopType.taoBao,
          items: [
            OrderItem(
                imageUrl:
                    'https://img.alicdn.com/bao/uploaded/i4/2842363615/O1CN01kOv4AT1cZiIe9i0gp_!!2842363615.jpg_80x80.jpg',
                title: '超大回车键发泄键盘程序员必备神器客服减压午睡枕三合一多功能',
                configuration: '均码;超大回车键',
                stock: 0,
                price: 29),
          ],
        ),
        ShoppingCartShop(
          shopName: 'Machome苹果家园上',
          shopType: ShopType.tianMao,
          items: [
            OrderItem(
                imageUrl:
                    'https://img.alicdn.com/bao/uploaded/i3/37656861/O1CN01Xq5z7720YNwJmcPlA_!!37656861.jpg_80x80.jpg',
                title: '2019新款Apple/苹果MacBook Pro MPXQ2CH/A笔记本电脑选配13 15',
                configuration: '19款15/2.3八核i9/16/512银MV932;邮寄;官方标配',
                stock: 0,
                price: 18770),
          ],
        ),
        ShoppingCartShop(
          shopName: '苏宁易购官方旗舰',
          shopType: ShopType.tianMao,
          hasCoupons: true,
          items: [
            OrderItem(
                imageUrl:
                    'https://img.alicdn.com/bao/uploaded/i5/TB1lpCRDHvpK1RjSZPivk2mwXXa_043412.jpg_80x80.jpg',
                title: '【下单低至4548元】Apple/苹果 iPhone 8 Plus 64G 全网通4G手机',
                configuration: '无需合约版;银色;官方标配;64GB',
                stock: 0,
                price: 4688),
          ],
        ),
      ];

  // ============================= 消息 =============================

  static const List<Conversation> conversations = [
    Conversation(
      type: '官方',
      avatar: 'assets/images/cainiaoyizhan.png',
      title: '菜鸟驿站',
      titleColor: 0xFF7f3410,
      createAt: '09:28',
      description: '手慢无！抢最高2019元大包',
      unReadCount: 2,
    ),
    Conversation(
      type: '官方',
      avatar: 'assets/images/taobaotoutiao.png',
      title: '淘宝头条',
      titleColor: 0xFF7f3410,
      createAt: '12:30',
      description: '这栋老宅被加价5000多万，还说买家赚钱了？',
      unReadCount: 8,
    ),
    Conversation(
      type: '官方',
      avatar: 'assets/images/88members.png',
      title: '淘气值',
      titleColor: 0xFF7f3410,
      createAt: '14:01',
      description: '88VIP 独家包场免费看《复仇4》',
      unReadCount: 10,
    ),
    Conversation(
      type: '品牌',
      avatar: 'assets/images/apple_home.png',
      title: '苹果家园',
      titleColor: 0xFF7f3410,
      createAt: '昨天',
      description: '亲，您看中的咨询的产品还没下单，请及时下单付款哟',
      unReadCount: 5,
    ),
  ];

  /// 聊天消息 mock
  static const List<ChatMessage> chatMessages = [
    ChatMessage(
        content: '在吗？亲，请问有什么可以帮您的吗？',
        isMe: false,
        time: '09:30'),
    ChatMessage(
        content: '我想问下这款手机现在有货吗？',
        isMe: true,
        time: '09:31'),
    ChatMessage(
        content: '亲，这款手机现货充足，拍下后 48 小时内发货哦～',
        isMe: false,
        time: '09:32'),
    ChatMessage(
        content: '好的，那我拍一台，能优惠点吗？',
        isMe: true,
        time: '09:33'),
    ChatMessage(
        content: '亲，现在活动价已经是最低价了呢，拍下送原装壳和钢化膜哦～',
        isMe: false,
        time: '09:34'),
  ];

  // ============================= 微淘 =============================

  static const List<PostModel> posts = [
    PostModel(
      name: '小米官方旗舰店',
      avatar: 'assets/images/apple_home.png',
      address: '广东 深圳',
      message: '小米9 骁龙855 全面屏 4800万三摄，现货开抢！',
      photos: [
        'https://img.alicdn.com/bao/uploaded/i5/TB1d4D5HQzoK1RjSZFlDP9i4VXa_121840.jpg',
        'https://img.alicdn.com/bao/uploaded/i5/TB1trAMNQPoK1RjSZKb.LB1IXXa_101123.jpg',
      ],
      readCount: 12890,
      likesCount: 345,
      commentsCount: 89,
      postTime: '10分钟前',
    ),
    PostModel(
      name: '华为官方旗舰店',
      avatar: 'assets/images/taobaotoutiao.png',
      address: '广东 东莞',
      message: '华为 P30 Pro 徕卡四摄，记录美好生活，限时直降 500！',
      photos: [
        'https://img.alicdn.com/bao/uploaded/i8/TB1uiAYNMHqK1RjSZFkXfd.WFXa_112352.jpg',
      ],
      readCount: 23500,
      likesCount: 1024,
      commentsCount: 230,
      postTime: '1小时前',
    ),
    PostModel(
      name: 'LG 官方旗舰店',
      avatar: 'assets/images/88members.png',
      address: '上海',
      message: '4K IPS 显示器，设计师的选择，色彩还原真实。',
      photos: [
        'https://img.alicdn.com/bao/uploaded/i1/2074230498/O1CN01lZnjxG1FY7lsf191X_!!0-item_pic.jpg',
      ],
      readCount: 8900,
      likesCount: 156,
      commentsCount: 45,
      postTime: '3小时前',
    ),
  ];
}
