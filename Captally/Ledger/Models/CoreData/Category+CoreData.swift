import Foundation
import CoreData

@objc(Category)
public class Category: NSManagedObject, Identifiable {
}

extension Category {
    @NSManaged public var icon: String
    @NSManaged public var id: UUID
    @NSManaged public var isSystem: Bool
    @NSManaged public var name: String
    @NSManaged public var parentId: UUID?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var type: String
    @NSManaged public var book: Book?
    @NSManaged public var transactions: NSSet?

    var categoryType: CategoryType {
        get { CategoryType(rawValue: type) ?? .expense }
        set { type = newValue.rawValue }
    }

    var isTopLevel: Bool {
        parentId == nil
    }

    var canDelete: Bool {
        !isSystem
    }

    static let defaultExpenseCategories: [(nameKey: String, icon: String, children: [(String, String)])] = [
        ("category.food", "fork.knife", [
            ("category.food.breakfast", "cup.and.saucer.fill"),
            ("category.food.lunch", "takeoutbag.and.cup.and.straw.fill"),
            ("category.food.dinner", "wineglass.fill"),
            ("category.food.snacks", "birthday.cake.fill"),
            ("category.food.drinks", "mug.fill"),
            ("category.food.fruits", "apple.fill"),
            ("category.food.takeout", "bag.fill")
        ]),
        ("category.transport", "car.fill", [
            ("category.transport.bus", "bus.fill"),
            ("category.transport.metro", "tram.fill"),
            ("category.transport.taxi", "car.side.fill"),
            ("category.transport.gas", "fuelpump.fill"),
            ("category.transport.parking", "parkingsign.circle.fill"),
            ("category.transport.toll", "building.columns.fill"),
            ("category.transport.bikeShare", "bicycle")
        ]),
        ("category.shopping", "bag.fill", [
            ("category.shopping.clothes", "shirt.fill"),
            ("category.shopping.dailyGoods", "house.fill"),
            ("category.shopping.electronics", "laptopcomputer.and.iphone"),
            ("category.shopping.cosmetics", "drop.fill"),
            ("category.shopping.shoesBags", "handbag.fill"),
            ("category.shopping.appliances", "tv.fill")
        ]),
        ("category.housing", "house.fill", [
            ("category.housing.rent", "building.fill"),
            ("category.housing.utilities", "bolt.fill"),
            ("category.housing.hoa", "building.2.fill"),
            ("category.housing.repairs", "wrench.and.screwdriver.fill"),
            ("category.housing.gasBill", "flame.fill"),
            ("category.housing.internet", "wifi")
        ]),
        ("category.entertainment", "gamecontroller.fill", [
            ("category.entertainment.movies", "film.fill"),
            ("category.entertainment.games", "gamecontroller.fill"),
            ("category.entertainment.travel", "airplane.departure"),
            ("category.entertainment.sports", "figure.run"),
            ("category.entertainment.music", "music.note"),
            ("category.entertainment.social", "person.2.fill")
        ]),
        ("category.healthcare", "stethoscope", [
            ("category.healthcare.clinic", "stethoscope"),
            ("category.healthcare.medicine", "pills.fill"),
            ("category.healthcare.checkup", "heart.text.square.fill"),
            ("category.healthcare.dental", "mouth.fill"),
            ("category.healthcare.wellness", "heart.circle.fill")
        ]),
        ("category.education", "book.fill", [
            ("category.education.training", "graduationcap.fill"),
            ("category.education.books", "book.fill"),
            ("category.education.courses", "character.book.fill"),
            ("category.education.exams", "doc.text.fill"),
            ("category.education.stationery", "pencil")
        ]),
        ("category.telecom", "phone.fill", [
            ("category.telecom.phoneBill", "phone.fill"),
            ("category.telecom.internet", "wifi"),
            ("category.telecom.membership", "person.crop.circle.fill"),
            ("category.telecom.delivery", "shippingbox.fill")
        ]),
        ("category.socialGifts", "gift.fill", [
            ("category.socialGifts.redEnvelope", "gift.fill"),
            ("category.socialGifts.cashGift", "banknote.fill"),
            ("category.socialGifts.hosting", "wineglass.fill"),
            ("category.socialGifts.gifts", "heart.fill")
        ]),
        ("category.pets", "pawprint.fill", [
            ("category.pets.catFood", "pawprint.fill"),
            ("category.pets.dogFood", "pawprint.fill"),
            ("category.pets.petHealthcare", "stethoscope"),
            ("category.pets.petSupplies", "bag.fill")
        ]),
    ]

    static let defaultIncomeCategories: [(nameKey: String, icon: String, children: [(String, String)])] = [
        ("category.salary", "banknote.fill", [
            ("category.salary.monthly", "banknote.fill"),
            ("category.salary.bonus", "gift.fill"),
            ("category.salary.overtime", "clock.fill"),
            ("category.salary.yearEndBonus", "star.fill")
        ]),
        ("category.investment", "chart.line.uptrend.xyaxis", [
            ("category.investment.stocks", "chart.line.uptrend.xyaxis"),
            ("category.investment.funds", "chart.bar.fill"),
            ("category.investment.interest", "percent"),
            ("category.investment.wealthMgmt", "coins")
        ]),
        ("category.sideJob", "briefcase.fill", [
            ("category.sideJob.freelance", "laptopcomputer.and.iphone"),
            ("category.sideJob.consulting", "person.wave.2.fill"),
            ("category.sideJob.royalties", "pencil.line")
        ]),
        ("category.otherIncome", "plus.circle.fill", [
            ("category.otherIncome.redEnvelope", "gift.fill"),
            ("category.otherIncome.refund", "arrow.uturn.backward.circle.fill"),
            ("category.otherIncome.reimbursement", "doc.text.fill"),
            ("category.otherIncome.lottery", "star.circle.fill")
        ]),
    ]

    static func createDefaultCategories(for book: Book, in context: NSManagedObjectContext) {
        var sortOrder: Int32 = 0

        for parent in defaultExpenseCategories {
            let parentCategory = Category(context: context)
            parentCategory.id = UUID()
            parentCategory.name = LocalizationManager.localized(parent.nameKey)
            parentCategory.icon = parent.icon
            parentCategory.categoryType = .expense
            parentCategory.sortOrder = sortOrder
            parentCategory.isSystem = true
            parentCategory.book = book
            sortOrder += 1

            for child in parent.children {
                let childCategory = Category(context: context)
                childCategory.id = UUID()
                childCategory.name = LocalizationManager.localized(child.0)
                childCategory.icon = child.1
                childCategory.categoryType = .expense
                childCategory.parentId = parentCategory.id
                childCategory.sortOrder = sortOrder
                childCategory.isSystem = true
                childCategory.book = book
                sortOrder += 1
            }
        }

        for parent in defaultIncomeCategories {
            let parentCategory = Category(context: context)
            parentCategory.id = UUID()
            parentCategory.name = LocalizationManager.localized(parent.nameKey)
            parentCategory.icon = parent.icon
            parentCategory.categoryType = .income
            parentCategory.sortOrder = sortOrder
            parentCategory.isSystem = true
            parentCategory.book = book
            sortOrder += 1

            for child in parent.children {
                let childCategory = Category(context: context)
                childCategory.id = UUID()
                childCategory.name = LocalizationManager.localized(child.0)
                childCategory.icon = child.1
                childCategory.categoryType = .income
                childCategory.parentId = parentCategory.id
                childCategory.sortOrder = sortOrder
                childCategory.isSystem = true
                childCategory.book = book
                sortOrder += 1
            }
        }
    }

    static func create(
        in context: NSManagedObjectContext,
        name: String,
        icon: String,
        categoryType: CategoryType,
        book: Book,
        parentId: UUID? = nil,
        sortOrder: Int32 = 0
    ) -> Category {
        let category = Category(context: context)
        category.id = UUID()
        category.name = name
        category.icon = icon
        category.categoryType = categoryType
        category.sortOrder = sortOrder
        category.isSystem = false
        category.parentId = parentId
        category.book = book
        return category
    }
}
