import SwiftUI

@MainActor
final class LocalizationManager: ObservableObject {
    @Published var language: Language {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "app.language")
        }
    }

    init(language: Language = .current) {
        self.language = language
    }

    subscript(_ key: String) -> String {
        table[language]?[key] ?? table[.en]?[key] ?? key
    }

    nonisolated static func localized(_ key: String) -> String {
        let lang = Language.current
        return table[lang]?[key] ?? table[.en]?[key] ?? key
    }

    private nonisolated static let table: [Language: [String: String]] = [
        .en: en,
        .zhHans: zhHans
    ]

    private var table: [Language: [String: String]] { Self.table }

    private nonisolated static let en: [String: String] = [
        // MARK: - Tab Bar
        "tab.record": "Record",
        "tab.bills": "Bills",
        "tab.stats": "Stats",
        "tab.ledgers": "Ledgers",
        "tab.settings": "Settings",

        // MARK: - Quick Entry
        "quickEntry.title": "Record",
        "quickEntry.noLedger": "Please create a ledger first",
        "quickEntry.expense": "Expense",
        "quickEntry.income": "Income",
        "quickEntry.saved": "Saved %@",
        "quickEntry.categories": "Categories",
        "quickEntry.note": "Note",
        "quickEntry.date": "Date",
        "quickEntry.notePlaceholder": "Add a note...",
        "quickEntry.done": "Done",
        "quickEntry.save": "Save",

        // MARK: - Bill List
        "bills.title": "Bills",
        "bills.search": "Search transactions",
        "bills.cancel": "Cancel",
        "bills.noLedger": "No Ledger",
        "bills.noLedgerDesc": "Create a ledger to start recording",
        "bills.noExpenses": "No expenses this month",
        "bills.keepItUp": "Keep it up! 🎉",
        "bills.expense": "Expense",
        "bills.income": "Income",
        "bills.balance": "Balance",
        "bills.delete": "Delete",

        // MARK: - Statistics
        "stats.title": "Stats",
        "stats.noData": "No ledger data yet",
        "stats.noDataDesc": "Create a ledger and start recording your finances\nEvery entry is the first step to financial management",
        "stats.period": "Period",
        "stats.week": "Week",
        "stats.month": "Month",
        "stats.year": "Year",
        "stats.trend": "Trend",
        "stats.noChartData": "No data",
        "stats.byCategory": "By Category",
        "stats.subcategories": "Subcategories",
        "stats.transactions": "Transactions",
        "stats.noRecords": "No records",
        "stats.close": "Close",
        "stats.date": "Date",
        "stats.amount": "Amount",
        "stats.category": "Category",

        // MARK: - Book Management
        "ledgers.title": "Ledgers",
        "ledgers.personal": "Personal",
        "ledgers.newLedger": "New Ledger",
        "ledgers.basicInfo": "Basic Info",
        "ledgers.ledgerName": "Ledger name",
        "ledgers.icon": "Icon",
        "ledgers.cancel": "Cancel",
        "ledgers.create": "Create",
        "ledgers.addBudget": "Add Budget",
        "ledgers.budgets": "Budgets",
        "ledgers.amount": "Amount",
        "ledgers.period": "Period",
        "ledgers.monthly": "Monthly",
        "ledgers.yearly": "Yearly",
        "ledgers.enterBudgetAmount": "Enter budget amount",
        "ledgers.add": "Add",

        // MARK: - Settings
        "settings.title": "Settings",
        "settings.general": "General",
        "settings.currency": "Currency",
        "settings.language": "Language",
        "settings.data": "Data",
        "settings.categories": "Categories",
        "settings.exportData": "Export Data",
        "settings.dataManagement": "Data Management",
        "settings.about": "About",
        "settings.version": "Version",
        "settings.privacyPolicy": "Privacy Policy",
        "settings.exportCSV": "Export as CSV",
        "settings.exportJSON": "Export as JSON",
        "settings.preview": "Preview",
        "settings.iCloudSync": "iCloud Sync",
        "settings.iCloudSyncDesc": "Data syncs automatically to iCloud, keeping consistent across devices",
        "settings.dataSecurity": "Data Security",
        "settings.dataSecurityDesc": "All data is stored only in your iCloud account and never uploaded to any third-party servers",
        "settings.cny": "CNY (¥)",
        "settings.usd": "USD ($)",
        "settings.eur": "EUR (€)",
        "settings.jpy": "JPY (¥)",

        // MARK: - Category List
        "categories.title": "Categories",
        "categories.type": "Type",
        "categories.expense": "Expense",
        "categories.income": "Income",
        "categories.topLevel": "Top-level",
        "categories.subLevel": "Sub-level",
        "categories.total": "Total",
        "categories.empty": "No categories",
        "categories.emptyHint": "Tap + to add a category",
        "categories.default": "Default",
        "categories.edit": "Edit",
        "categories.delete": "Delete",
        "categories.addCategory": "Add Category",
        "categories.editCategory": "Edit Category",
        "categories.cancel": "Cancel",
        "categories.add": "Add",
        "categories.save": "Save",
        "categories.categoryName": "Category name",
        "categories.chooseIcon": "Choose Icon",
        "categories.sortCategories": "Sort Categories",
        "categories.done": "Done",
        "categories.error": "Error",
        "categories.ok": "OK",
        "categories.addSubcategory": "Add Subcategory",
        "categories.parent": "Parent",

        // MARK: - Member List

        // MARK: - Share Book

        // MARK: - Split Setup

        // MARK: - Category Sort

        // MARK: - Budget Progress
        "budget.monthly": "Monthly Budget",
        "budget.yearly": "Yearly Budget",
        "budget.overBudget": "Over budget",
        "budget.remaining": "Remaining",

        // MARK: - Components
        "component.uncategorized": "Uncategorized",
        "component.topLevelCategory": "Top-level",
        "component.subLevelCategory": "Sub-level",
        "component.noCategories": "No categories",
        "component.addCategory": "Add Category",
        "component.add": "Add",

        // MARK: - Notifications
        "notification.budgetOverrun": "Budget Overrun Alert",
        "notification.overBudgetBy": "Over budget by %@",
        "notification.dailyReminder": "Recording Reminder",
        "notification.reminderBody": "Don't forget to record today's expenses",

        // MARK: - Services
        "service.signInICloud": "Please sign in to your iCloud account first",

        // MARK: - Validation
        "validation.enterCategoryName": "Please enter a category name",
        "validation.saveFailed": "Save failed: %@",
        "validation.cannotDeleteDefault": "Default categories cannot be deleted",
        "validation.categoryHasRecords": "This category has %d records and cannot be deleted",

        // MARK: - Common
        "common.delete": "Delete",
        "common.cancel": "Cancel",
        "common.save": "Save",
        "common.add": "Add",
        "common.done": "Done",
        "common.edit": "Edit",
        "common.ok": "OK",
        "common.error": "Error",

        // MARK: - Categories (Expense)
        "category.food": "Food",
        "category.food.breakfast": "Breakfast",
        "category.food.lunch": "Lunch",
        "category.food.dinner": "Dinner",
        "category.food.snacks": "Snacks",
        "category.food.drinks": "Drinks",
        "category.food.fruits": "Fruits",
        "category.food.takeout": "Takeout",

        "category.transport": "Transport",
        "category.transport.bus": "Bus",
        "category.transport.metro": "Metro",
        "category.transport.taxi": "Taxi",
        "category.transport.gas": "Gas",
        "category.transport.parking": "Parking",
        "category.transport.toll": "Toll",
        "category.transport.bikeShare": "Bike Share",

        "category.shopping": "Shopping",
        "category.shopping.clothes": "Clothes",
        "category.shopping.dailyGoods": "Daily Goods",
        "category.shopping.electronics": "Electronics",
        "category.shopping.cosmetics": "Cosmetics",
        "category.shopping.shoesBags": "Shoes & Bags",
        "category.shopping.appliances": "Appliances",

        "category.housing": "Housing",
        "category.housing.rent": "Rent",
        "category.housing.utilities": "Utilities",
        "category.housing.hoa": "HOA",
        "category.housing.repairs": "Repairs",
        "category.housing.gasBill": "Gas Bill",
        "category.housing.internet": "Internet",

        "category.entertainment": "Entertainment",
        "category.entertainment.movies": "Movies",
        "category.entertainment.games": "Games",
        "category.entertainment.travel": "Travel",
        "category.entertainment.sports": "Sports",
        "category.entertainment.music": "Music",
        "category.entertainment.social": "Social",

        "category.healthcare": "Healthcare",
        "category.healthcare.clinic": "Clinic",
        "category.healthcare.medicine": "Medicine",
        "category.healthcare.checkup": "Checkup",
        "category.healthcare.dental": "Dental",
        "category.healthcare.wellness": "Wellness",

        "category.education": "Education",
        "category.education.training": "Training",
        "category.education.books": "Books",
        "category.education.courses": "Courses",
        "category.education.exams": "Exams",
        "category.education.stationery": "Stationery",

        "category.telecom": "Telecom",
        "category.telecom.phoneBill": "Phone Bill",
        "category.telecom.internet": "Internet",
        "category.telecom.membership": "Membership",
        "category.telecom.delivery": "Delivery",

        "category.socialGifts": "Social Gifts",
        "category.socialGifts.redEnvelope": "Red Envelope",
        "category.socialGifts.cashGift": "Cash Gift",
        "category.socialGifts.hosting": "Hosting",
        "category.socialGifts.gifts": "Gifts",

        "category.pets": "Pets",
        "category.pets.catFood": "Cat Food",
        "category.pets.dogFood": "Dog Food",
        "category.pets.petHealthcare": "Pet Healthcare",
        "category.pets.petSupplies": "Pet Supplies",

        // MARK: - Categories (Income)
        "category.salary": "Salary",
        "category.salary.monthly": "Monthly",
        "category.salary.bonus": "Bonus",
        "category.salary.overtime": "Overtime",
        "category.salary.yearEndBonus": "Year-end Bonus",

        "category.investment": "Investment",
        "category.investment.stocks": "Stocks",
        "category.investment.funds": "Funds",
        "category.investment.interest": "Interest",
        "category.investment.wealthMgmt": "Wealth Mgmt",

        "category.sideJob": "Side Job",
        "category.sideJob.freelance": "Freelance",
        "category.sideJob.consulting": "Consulting",
        "category.sideJob.royalties": "Royalties",

        "category.otherIncome": "Other Income",
        "category.otherIncome.redEnvelope": "Red Envelope",
        "category.otherIncome.refund": "Refund",
        "category.otherIncome.reimbursement": "Reimbursement",
        "category.otherIncome.lottery": "Lottery",

        // MARK: - Demo Data
        "demo.dailyExpenses": "Daily Expenses",
        "demo.familyLedger": "Family Ledger",
        "demo.me": "Me",
        "demo.partner": "Partner",
        "demo.mom": "Mom",
        "demo.breakfast": "Breakfast",
        "demo.lunch": "Lunch",
        "demo.dinner": "Dinner",
        "demo.bus": "Bus",
        "demo.metro": "Metro",
        "demo.taxi": "Taxi",
        "demo.gas": "Gas",
        "demo.grocery": "Grocery",
        "demo.dailyNecessities": "Daily necessities",
        "demo.clothes": "Clothes",
        "demo.movie": "Movie",
        "demo.game": "Game",
        "demo.party": "Party",
        "demo.rent": "Rent",
        "demo.utilities": "Utilities",
        "demo.phoneBill": "Phone bill",
        "demo.salary": "Salary",
        "demo.groceryShopping": "Grocery shopping",
        "demo.householdItems": "Household items",
        "demo.utilityBills": "Utility bills",
        "demo.familyDinner": "Family dinner"
    ]

    private nonisolated static let zhHans: [String: String] = [
        // MARK: - Tab Bar
        "tab.record": "记账",
        "tab.bills": "账单",
        "tab.stats": "统计",
        "tab.ledgers": "账本",
        "tab.settings": "设置",

        // MARK: - Quick Entry
        "quickEntry.title": "记账",
        "quickEntry.noLedger": "请先创建一个账本",
        "quickEntry.expense": "支出",
        "quickEntry.income": "收入",
        "quickEntry.saved": "已记录 %@",
        "quickEntry.categories": "分类管理",
        "quickEntry.note": "备注",
        "quickEntry.date": "日期",
        "quickEntry.notePlaceholder": "添加备注...",
        "quickEntry.done": "完成",
        "quickEntry.save": "保存",

        // MARK: - Bill List
        "bills.title": "账单",
        "bills.search": "搜索交易记录",
        "bills.cancel": "取消",
        "bills.noLedger": "暂无账本",
        "bills.noLedgerDesc": "创建一个账本开始记账",
        "bills.noExpenses": "这个月还没有支出记录",
        "bills.keepItUp": "继续保持！🎉",
        "bills.expense": "支出",
        "bills.income": "收入",
        "bills.balance": "结余",
        "bills.delete": "删除",

        // MARK: - Statistics
        "stats.title": "统计",
        "stats.noData": "还没有账本数据",
        "stats.noDataDesc": "创建一个账本，开始记录你的收支\n每一笔记录都是理财的第一步",
        "stats.period": "时段",
        "stats.week": "周",
        "stats.month": "月",
        "stats.year": "年",
        "stats.trend": "收支趋势",
        "stats.noChartData": "暂无数据",
        "stats.byCategory": "分类占比",
        "stats.subcategories": "二级分类",
        "stats.transactions": "交易记录",
        "stats.noRecords": "暂无记录",
        "stats.close": "关闭",
        "stats.date": "日期",
        "stats.amount": "金额",
        "stats.category": "分类",

        // MARK: - Book Management
        "ledgers.title": "账本",
        "ledgers.personal": "个人账本",
        "ledgers.newLedger": "新建账本",
        "ledgers.basicInfo": "基本信息",
        "ledgers.ledgerName": "账本名称",
        "ledgers.icon": "图标",
        "ledgers.cancel": "取消",
        "ledgers.create": "创建",
        "ledgers.addBudget": "添加预算",
        "ledgers.budgets": "预算管理",
        "ledgers.amount": "金额",
        "ledgers.period": "周期",
        "ledgers.monthly": "月度",
        "ledgers.yearly": "年度",
        "ledgers.enterBudgetAmount": "输入预算金额",
        "ledgers.add": "添加",

        // MARK: - Settings
        "settings.title": "设置",
        "settings.general": "通用",
        "settings.currency": "货币",
        "settings.language": "语言",
        "settings.data": "数据",
        "settings.categories": "分类管理",
        "settings.exportData": "导出数据",
        "settings.dataManagement": "数据管理",
        "settings.about": "关于",
        "settings.version": "版本",
        "settings.privacyPolicy": "隐私政策",
        "settings.exportCSV": "导出为 CSV",
        "settings.exportJSON": "导出为 JSON",
        "settings.preview": "预览",
        "settings.iCloudSync": "iCloud 同步",
        "settings.iCloudSyncDesc": "数据自动同步至 iCloud，跨设备保持一致",
        "settings.dataSecurity": "数据安全",
        "settings.dataSecurityDesc": "所有数据仅存储在您的 iCloud 账户中，不会上传至任何第三方服务器",
        "settings.cny": "人民币 (CNY)",
        "settings.usd": "美元 (USD)",
        "settings.eur": "欧元 (EUR)",
        "settings.jpy": "日元 (JPY)",

        // MARK: - Category List
        "categories.title": "分类管理",
        "categories.type": "类型",
        "categories.expense": "支出",
        "categories.income": "收入",
        "categories.topLevel": "一级分类",
        "categories.subLevel": "二级分类",
        "categories.total": "总计",
        "categories.empty": "暂无分类",
        "categories.emptyHint": "点击右上角 + 添加分类",
        "categories.default": "默认分类",
        "categories.edit": "编辑",
        "categories.delete": "删除",
        "categories.addCategory": "添加分类",
        "categories.editCategory": "编辑分类",
        "categories.cancel": "取消",
        "categories.add": "添加",
        "categories.save": "保存",
        "categories.categoryName": "分类名称",
        "categories.chooseIcon": "选择图标",
        "categories.sortCategories": "排序分类",
        "categories.done": "完成",
        "categories.error": "错误",
        "categories.ok": "确定",
        "categories.addSubcategory": "添加子分类",
        "categories.parent": "父分类",

        // MARK: - Member List

        // MARK: - Share Book

        // MARK: - Split Setup

        // MARK: - Category Sort

        // MARK: - Budget Progress
        "budget.monthly": "月度预算",
        "budget.yearly": "年度预算",
        "budget.overBudget": "已超支",
        "budget.remaining": "剩余",

        // MARK: - Components
        "component.uncategorized": "未分类",
        "component.topLevelCategory": "一级分类",
        "component.subLevelCategory": "二级分类",
        "component.noCategories": "暂无分类",
        "component.addCategory": "添加分类",
        "component.add": "添加",

        // MARK: - Notifications
        "notification.budgetOverrun": "预算超支提醒",
        "notification.overBudgetBy": "已超支 %@",
        "notification.dailyReminder": "记账提醒",
        "notification.reminderBody": "别忘了记录今天的开支哦",

        // MARK: - Services
        "service.signInICloud": "请先登录 iCloud 账户",

        // MARK: - Validation
        "validation.enterCategoryName": "请输入分类名称",
        "validation.saveFailed": "保存失败：%@",
        "validation.cannotDeleteDefault": "系统默认分类不能删除",
        "validation.categoryHasRecords": "该分类下已有 %d 条记录，无法删除",

        // MARK: - Common
        "common.delete": "删除",
        "common.cancel": "取消",
        "common.save": "保存",
        "common.add": "添加",
        "common.done": "完成",
        "common.edit": "编辑",
        "common.ok": "确定",
        "common.error": "错误",

        // MARK: - Categories (Expense)
        "category.food": "餐饮",
        "category.food.breakfast": "早餐",
        "category.food.lunch": "午餐",
        "category.food.dinner": "晚餐",
        "category.food.snacks": "零食",
        "category.food.drinks": "饮品",
        "category.food.fruits": "水果",
        "category.food.takeout": "外卖",

        "category.transport": "交通",
        "category.transport.bus": "公交",
        "category.transport.metro": "地铁",
        "category.transport.taxi": "打车",
        "category.transport.gas": "加油",
        "category.transport.parking": "停车",
        "category.transport.toll": "过路费",
        "category.transport.bikeShare": "共享单车",

        "category.shopping": "购物",
        "category.shopping.clothes": "衣服",
        "category.shopping.dailyGoods": "日用品",
        "category.shopping.electronics": "电子产品",
        "category.shopping.cosmetics": "化妆品",
        "category.shopping.shoesBags": "鞋包",
        "category.shopping.appliances": "家电",

        "category.housing": "居住",
        "category.housing.rent": "房租",
        "category.housing.utilities": "水电",
        "category.housing.hoa": "物业费",
        "category.housing.repairs": "维修",
        "category.housing.gasBill": "燃气费",
        "category.housing.internet": "网费",

        "category.entertainment": "娱乐",
        "category.entertainment.movies": "电影",
        "category.entertainment.games": "游戏",
        "category.entertainment.travel": "旅行",
        "category.entertainment.sports": "运动",
        "category.entertainment.music": "音乐",
        "category.entertainment.social": "社交",

        "category.healthcare": "医疗",
        "category.healthcare.clinic": "门诊",
        "category.healthcare.medicine": "药品",
        "category.healthcare.checkup": "体检",
        "category.healthcare.dental": "牙科",
        "category.healthcare.wellness": "保健",

        "category.education": "教育",
        "category.education.training": "培训",
        "category.education.books": "书籍",
        "category.education.courses": "课程",
        "category.education.exams": "考试",
        "category.education.stationery": "文具",

        "category.telecom": "通讯",
        "category.telecom.phoneBill": "话费",
        "category.telecom.internet": "网费",
        "category.telecom.membership": "会员",
        "category.telecom.delivery": "快递",

        "category.socialGifts": "人情礼物",
        "category.socialGifts.redEnvelope": "红包",
        "category.socialGifts.cashGift": "礼金",
        "category.socialGifts.hosting": "请客",
        "category.socialGifts.gifts": "礼物",

        "category.pets": "宠物",
        "category.pets.catFood": "猫粮",
        "category.pets.dogFood": "狗粮",
        "category.pets.petHealthcare": "宠物医疗",
        "category.pets.petSupplies": "宠物用品",

        // MARK: - Categories (Income)
        "category.salary": "工资",
        "category.salary.monthly": "月薪",
        "category.salary.bonus": "奖金",
        "category.salary.overtime": "加班费",
        "category.salary.yearEndBonus": "年终奖",

        "category.investment": "投资",
        "category.investment.stocks": "股票",
        "category.investment.funds": "基金",
        "category.investment.interest": "利息",
        "category.investment.wealthMgmt": "理财",

        "category.sideJob": "兼职",
        "category.sideJob.freelance": "自由职业",
        "category.sideJob.consulting": "咨询",
        "category.sideJob.royalties": "版税",

        "category.otherIncome": "其他收入",
        "category.otherIncome.redEnvelope": "红包",
        "category.otherIncome.refund": "退款",
        "category.otherIncome.reimbursement": "报销",
        "category.otherIncome.lottery": "彩票",

        // MARK: - Demo Data
        "demo.dailyExpenses": "日常开销",
        "demo.familyLedger": "家庭账本",
        "demo.me": "我",
        "demo.partner": "伴侣",
        "demo.mom": "妈妈",
        "demo.breakfast": "早餐",
        "demo.lunch": "午餐",
        "demo.dinner": "晚餐",
        "demo.bus": "公交",
        "demo.metro": "地铁",
        "demo.taxi": "打车",
        "demo.gas": "加油",
        "demo.grocery": "超市购物",
        "demo.dailyNecessities": "日用品",
        "demo.clothes": "衣服",
        "demo.movie": "电影",
        "demo.game": "游戏",
        "demo.party": "聚会",
        "demo.rent": "房租",
        "demo.utilities": "水电",
        "demo.phoneBill": "话费",
        "demo.salary": "月薪",
        "demo.groceryShopping": "超市采购",
        "demo.householdItems": "家庭用品",
        "demo.utilityBills": "水电费",
        "demo.familyDinner": "家庭晚餐"
    ]
}
