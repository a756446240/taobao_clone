import '../models/models.dart';

/// Mock 数据层（全新架构：所有数据集中管理，离线可用）
class MockData {
  MockData._();

  // ============================= 首页 =============================

  /// 热搜词库（大池子，覆盖母婴/美妆/食品/家居/服饰/数码/宠物等，
  /// 搜索页每次随机抽 10 个上榜，避免整榜都是同一品类）
  static const List<String> searchHints = [
    '纸尿裤nb码',
    '帮宝适拉拉裤xl',
    '婴幼儿益生菌滴剂',
    '儿童保温杯316',
    '宝宝辅食料理机',
    '美白牙膏去黄',
    '氨基酸洗面奶',
    '防晒霜spf50+',
    '玻尿酸补水面膜',
    '哑光口红正红色',
    '隐形眼镜护理液',
    '褪黑素睡眠软糖',
    '维生素c泡腾片',
    '乳清蛋白粉健身',
    '每日坚果混合装',
    '柳州螺蛳粉加臭',
    '手冲咖啡豆耶加雪菲',
    '无糖气泡水整箱',
    '泰国椰子水',
    '空气炸锅家用新款',
    '懒人沙发榻榻米',
    '全棉四件套1.8米',
    '香薰蜡烛礼盒',
    '收纳箱特大号',
    '瑜伽垫加厚防滑',
    '运动蓝牙耳机',
    '机械键盘青轴',
    '充电宝20000毫安',
    '恒温电热水壶',
    '豆腐猫砂除臭',
    '幼犬通用狗粮',
    '帆布包ins风',
    '老爹鞋女增高',
    '卫衣连帽加绒',
    '牛仔外套oversize',
    '敏感肌修护精华',
    '温和卸妆油',
    '电动牙刷声波',
    '负离子吹风机',
    '全自动足浴盆',
  ];

  /// 首页图标区 第 1 页（单行 5 个均分整宽，图标下不显示文字；原半露的"红包签到"已删除）
  static const List<HomeIconEntry> homeIconPage1 = [
    HomeIconEntry('天猫超市', '超市', 0xFF22c55e, 'assets/images/icons/chaoshi.png'),
    HomeIconEntry('淘宝秒杀', '秒', 0xFFff2d2d, 'assets/images/icons/miaosha.png'),
    HomeIconEntry('领淘金币', '币', 0xFFf7b500, 'assets/images/icons/coin.png'),
    HomeIconEntry('88VIP', '88', 0xFF2b2b2b, 'assets/images/icons/vip88.png'),
    HomeIconEntry('芭芭农场', '领', 0xFFff4d4f, 'assets/images/icons/farm.png'),
  ];

  /// 首页图标区 第 2 页（3 行 × 5 = 15 个，全部唯一不重复）
  static const List<HomeIconEntry> homeIconPage2 = [
    HomeIconEntry('聚划算', '聚', 0xFFe11d74, 'assets/images/icons/jubuy.png'),
    HomeIconEntry('天猫新品', '新品', 0xFFa98548, 'assets/images/icons/tianmao_new.png'),
    HomeIconEntry('分类', '三', 0xFF8b5cf6, 'assets/images/icons/category.png'),
    HomeIconEntry('活动日历', '历', 0xFFf43f5e, 'assets/images/icons/calendar.png'),
    HomeIconEntry('试用领取', 'U', 0xFFef4444, 'assets/images/icons/tryout.png'),
    HomeIconEntry('淘工厂', '厂', 0xFFff6a00, 'assets/images/icons/taogongchang.png'),
    HomeIconEntry('游戏中心', '游', 0xFFf97316, 'assets/images/icons/game.png'),
    HomeIconEntry('飞猪旅行', '猪', 0xFFfbbf24, 'assets/images/icons/feizhu.png'),
    HomeIconEntry('连连消', '消', 0xFFa855f7, 'assets/images/icons/lianlian.png'),
    HomeIconEntry('充值中心', '充', 0xFFff8c00, 'assets/images/icons/recharge.png'),
    HomeIconEntry('淘宝闪购', '购', 0xFFff7d00, 'assets/images/icons/flashbuy.png'),
    HomeIconEntry('淘鲜达', '鲜', 0xFF22c55e, 'assets/images/icons/fresh.png'),
    HomeIconEntry('淘宝礼物', '礼', 0xFFef4444, 'assets/images/icons/gift.png'),
    HomeIconEntry('全部频道', '●', 0xFFf59e0b, 'assets/images/icons/all_channels.png'),
    HomeIconEntry('淘票票', '票', 0xFFff4d4f, 'assets/images/icons/piaowu.png'),
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

  /// 猜你喜欢商品流（图+名一一对应，使用素材库真实商品图）
  static const List<SearchResultItem> guessLikeGoods = [
    SearchResultItem(
        imageUrl: 'assets/materials/mat01.jpg',
        title: '泰国进口WANGPROM汪逢姜黄膏50g 原装正品',
        shopName: '如意母婴正品',
        price: '39.9',
        commentCount: '已售8000+',
        goodRate: '98%好评'),
    SearchResultItem(
        imageUrl: 'assets/materials/mat02.jpg',
        title: 'SINE SHAPE六联活菌即食型益生菌25g 肠道调理',
        shopName: 'SINE海外旗舰店',
        price: '89',
        commentCount: '已售3000+',
        goodRate: '97%好评'),
    SearchResultItem(
        imageUrl: 'assets/materials/mat03.jpg',
        title: 'Aodeocare儿童保湿面霜50g 6-18岁学生专研',
        shopName: 'AODEOCARE旗舰店',
        price: '69',
        commentCount: '已售1万+',
        goodRate: '99%好评'),
    SearchResultItem(
        imageUrl: 'assets/materials/mat04.jpg',
        title: '美国进口SOLGAR甲钴胺维生素B12 5000mcg*60粒',
        shopName: 'SOLGAR海外旗舰店',
        price: '129',
        commentCount: '已售5000+',
        goodRate: '98%好评'),
    SearchResultItem(
        imageUrl: 'assets/materials/mat05.jpg',
        title: 'bionique Root Revive毛毛饮 养发口服液18支装',
        shopName: 'bionique海外旗舰店',
        price: '199',
        commentCount: '已售2000+',
        goodRate: '96%好评'),
    SearchResultItem(
        imageUrl: 'assets/materials/mat06.jpg',
        title: '澳洲Healthy Care橄榄叶精华胶囊3000mg*100粒',
        shopName: 'HealthyCare海外旗舰店',
        price: '109',
        commentCount: '已售9000+',
        goodRate: '98%好评'),
    SearchResultItem(
        imageUrl: 'assets/materials/mat07.jpg',
        title: '韩国直邮EXTREME男士综合维生素All in One 30日量',
        shopName: 'EXTREME海外旗舰店',
        price: '159',
        commentCount: '已售4000+',
        goodRate: '97%好评'),
    SearchResultItem(
        imageUrl: 'assets/materials/mat08.jpg',
        title: '美国拜耳MiraLAX聚乙二醇3350通便粉578g',
        shopName: '拜耳海外旗舰店',
        price: '145',
        commentCount: '已售2万+',
        goodRate: '99%好评'),
    SearchResultItem(
        imageUrl: 'assets/materials/mat09.jpg',
        title: 'Aodeocare舒缓保湿喷雾100ml*2瓶 法国活泉水',
        shopName: 'AODEOCARE旗舰店',
        price: '79',
        commentCount: '已售6000+',
        goodRate: '98%好评'),
    SearchResultItem(
        imageUrl: 'assets/materials/mat10.jpg',
        title: '法国ZzzQuil褪黑素睡眠片30粒 森林水果味',
        shopName: 'ZzzQuil海外旗舰店',
        price: '99',
        commentCount: '已售1万+',
        goodRate: '97%好评'),
    SearchResultItem(
        imageUrl: 'assets/materials/mat11.jpg',
        title: 'Aodeocare儿童舒缓保湿面膜25ml*5片 晒后修护',
        shopName: 'AODEOCARE旗舰店',
        price: '59',
        commentCount: '已售7000+',
        goodRate: '98%好评'),
    SearchResultItem(
        imageUrl: 'assets/materials/mat12.jpg',
        title: '日本资生堂IHADA防花粉喷雾 阻隔PM2.5隐形口罩',
        shopName: '资生堂海外旗舰店',
        price: '88',
        commentCount: '已售3000+',
        goodRate: '96%好评'),
    SearchResultItem(
        imageUrl: 'assets/materials/mat13.jpg',
        title: '美国Refresh OPTIVE MEGA-3人工泪液滴眼液70支',
        shopName: 'Refresh海外旗舰店',
        price: '115',
        commentCount: '已售5000+',
        goodRate: '98%好评'),
    SearchResultItem(
        imageUrl: 'assets/materials/mat14.jpg',
        title: '韩国直邮SOLAR-C维生素C咀嚼片220mg*80粒',
        shopName: 'SOLAR-C海外旗舰店',
        price: '69',
        commentCount: '已售1万+',
        goodRate: '97%好评'),
    SearchResultItem(
        imageUrl: 'assets/materials/mat15.jpg',
        title: '日本KB AIR MASK挂脖便携负离子空气净化器',
        shopName: 'KBAIRMASK海外旗舰店',
        price: '268',
        commentCount: '已售1000+',
        goodRate: '95%好评'),
    SearchResultItem(
        imageUrl: 'assets/materials/mat16.jpg',
        title: '日本Eisai Chocola BB Plus维生素B2 180锭',
        shopName: 'Eisai海外旗舰店',
        price: '135',
        commentCount: '已售8000+',
        goodRate: '98%好评'),
    SearchResultItem(
        imageUrl: 'assets/materials/mat17.jpg',
        title: 'bn HEALTHY维生素D3+K2+镁软胶囊3000IU*180粒',
        shopName: 'bnHEALTHY海外旗舰店',
        price: '149',
        commentCount: '已售4000+',
        goodRate: '97%好评'),
  ];

  // ============================= 搜索 =============================

  /// 关键词搜索结果：真实素材池中匹配的商品排前面，
  /// 再按关键词确定性生成一批标题含关键词的商品补足一屏（哈希假数据，
  /// 同一关键词每次结果一致）。
  static List<SearchResultItem> searchGoods(String keyword) {
    final kw = keyword.trim();
    if (kw.isEmpty) return List.of(guessLikeGoods);

    // 1) 真实池匹配：整词命中优先，其次按字符覆盖率
    int scoreOf(String title) {
      if (title.contains(kw)) return 100;
      if (kw.length < 2) return title.contains(kw) ? 100 : 0;
      var hit = 0;
      for (final ch in kw.split('')) {
        if (title.contains(ch)) hit++;
      }
      final ratio = hit / kw.length;
      return ratio >= 0.5 ? (ratio * 60).round() : 0;
    }

    final matched = guessLikeGoods
        .where((e) => scoreOf(e.title) > 0)
        .toList()
      ..sort((a, b) => scoreOf(b.title).compareTo(scoreOf(a.title)));

    // 2) 关键词确定性生成（保证一屏 20+ 条且标题都含关键词）
    int hash(String s) {
      var h = 0;
      for (final c in s.codeUnits) {
        h = (h * 31 + c) & 0x7fffffff;
      }
      return h;
    }

    const titleTemplates = [
      '{kw} 官方旗舰店正品包邮',
      '{kw} 热卖爆款 当季新款',
      '进口{kw} 免税仓直邮',
      '{kw} 大促特价 假一赔十',
      '{kw} 家庭装实惠装',
      '【品牌直营】{kw} 专柜同款',
      '{kw} 升级版 买二送一',
      '{kw} 网红同款 抖音热推',
      '{kw} 礼盒装 送礼佳品',
      '{kw} 工厂直供 一件代发',
      '新款{kw} 48小时发货',
      '{kw} 测评推荐 万人回购',
      '{kw} 清仓特价 库存有限',
      '{kw} 高端定制 品质保证',
      '{kw} 学生党平价好物',
      '{kw} 套装组合更划算',
      '正品{kw} 支持验货',
      '{kw} 限时秒杀 今日特价',
      '{kw} 加量不加价',
      '{kw} 老客专享复购装',
    ];
    const shopSuffixes = ['旗舰店', '专营店', '海外旗舰店', '官方自营店', '品牌直销店'];
    // 店名取关键词前 2~4 个字做"品牌"，避免全叫一个名
    final brand = kw.length <= 4 ? kw : kw.substring(0, 4);

    final generated = <SearchResultItem>[];
    for (var i = 0; i < titleTemplates.length; i++) {
      final h = hash('$kw#$i');
      final title = titleTemplates[i].replaceAll('{kw}', kw);
      final shop = '$brand${shopSuffixes[h % shopSuffixes.length]}';
      final price = (9 + h % 990) + (h % 100) / 100;
      final sold = h % 90000 + 1000;
      final soldText = sold >= 10000
          ? '已售${(sold / 10000).toStringAsFixed(1)}万+'
          : '已售$sold+';
      generated.add(SearchResultItem(
        imageUrl:
            'assets/materials/mat${(h % 17 + 1).toString().padLeft(2, '0')}.jpg',
        title: title,
        shopName: shop,
        price: price.toStringAsFixed(2),
        commentCount: soldText,
        goodRate: '${95 + h % 5}%好评',
      ));
    }

    // 去重（真实池与生成池标题相同的情况）后合并
    final seen = <String>{};
    return [
      for (final e in [...matched, ...generated])
        if (seen.add(e.title)) e,
    ];
  }

  /// 搜索联想词：热搜词库 + 真实商品标题中匹配输入的词，去重后返回
  static List<String> searchSuggestions(String input) {
    final kw = input.trim();
    if (kw.isEmpty) return const [];
    final out = <String>[];
    final seen = <String>{};
    void add(String s) {
      if (seen.add(s)) out.add(s);
    }

    for (final h in searchHints) {
      if (h.contains(kw)) add(h);
    }
    for (final g in guessLikeGoods) {
      if (g.title.contains(kw)) add(g.title);
    }
    // 输入本身不在词库时也兜底给出，保证一定能搜
    add(kw);
    return out.take(10).toList();
  }

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

}
