import Foundation

// MARK: - FlightResponse
public struct FlightResponse: Codable {
    let requestID, clientID: String
    let data: DataClass
    let providerType, responseVersion: String
    let status: Int
    let request: Request
    let reqLang, brand: String
    let almatarHeaders: AlmatarHeaders

    enum CodingKeys: String, CodingKey {
        case requestID = "requestId"
        case clientID = "clientId"
        case data, providerType, responseVersion, status, request, reqLang, brand, almatarHeaders
    }
}

// MARK: - AlmatarHeaders
struct AlmatarHeaders: Codable {
    let xRequestID, xBrand, xB3Traceid, xB3Spanid: String
    let xB3Parentspanid, xB3Sampled: String

    enum CodingKeys: String, CodingKey {
        case xRequestID = "x-request-id"
        case xBrand = "x-brand"
        case xB3Traceid = "x-b3-traceid"
        case xB3Spanid = "x-b3-spanid"
        case xB3Parentspanid = "x-b3-parentspanid"
        case xB3Sampled = "x-b3-sampled"
    }
}

// MARK: - DataClass
struct DataClass: Codable {
    let dataRequestID: String
    let resources: Resources
    let itineraries: [[String: Itinerary]]
    let legs: [String: LegValue]
    let segments: [String: Segment]
    let filters: Filters
    let staticData: StaticData
    let availableItineraries: Int
    let requestID: String

    enum CodingKeys: String, CodingKey {
        case dataRequestID = "requestId"
        case resources, itineraries, legs, segments, filters
        case staticData
        case availableItineraries = "AvailableItineraries"
        case requestID = "RequestId"
    }
}

// MARK: - Filters
struct Filters: Codable {
    let price: Price
    let airlines: [Airline]
    let airports: [Airport]
    let aircraft, cabin: [AircraftElement]
    let timings: Timings
    let stopsCount: [Int]
    let duration: Duration
    let stopAirports: [StopAirport]

    enum CodingKeys: String, CodingKey {
        case price = "Price"
        case airlines = "Airlines"
        case airports = "Airports"
        case aircraft = "Aircraft"
        case cabin = "Cabin"
        case timings = "Timings"
        case stopsCount = "StopsCount"
        case duration = "Duration"
        case stopAirports = "StopAirports"
    }
}

// MARK: - AircraftElement
struct AircraftElement: Codable {
    let code, name: String

    enum CodingKeys: String, CodingKey {
        case code = "Code"
        case name = "Name"
    }
}

// MARK: - Airline
struct Airline: Codable {
    let code: LegValidatingCarrierCode
    let name, logoURL: String

    enum CodingKeys: String, CodingKey {
        case code = "Code"
        case name = "Name"
        case logoURL = "LogoUrl"
    }
}

enum LegValidatingCarrierCode: String, Codable {
    case xy = "XY"
}

// MARK: - Airport
struct Airport: Codable {
    let airportCode, airportName, cityName, direction: String

    enum CodingKeys: String, CodingKey {
        case airportCode = "AirportCode"
        case airportName = "AirportName"
        case cityName = "CityName"
        case direction = "Direction"
    }
}

// MARK: - Duration
struct Duration: Codable {
    let stops, iteneraries: Iteneraries

    enum CodingKeys: String, CodingKey {
        case stops = "Stops"
        case iteneraries = "Iteneraries"
    }
}

// MARK: - Iteneraries
struct Iteneraries: Codable {
    let min: Int
    let max: Double

    enum CodingKeys: String, CodingKey {
        case min = "Min"
        case max = "Max"
    }
}

// MARK: - Price
struct Price: Codable {
    let perItinerary, perPerson: Iteneraries

    enum CodingKeys: String, CodingKey {
        case perItinerary = "PerItinerary"
        case perPerson = "PerPerson"
    }
}

// MARK: - StopAirport
struct StopAirport: Codable {
    let city, airport: String
    let airportCode: LegArrivalAirportCode

    enum CodingKeys: String, CodingKey {
        case city = "City"
        case airport = "Airport"
        case airportCode = "AirportCode"
    }
}

enum LegArrivalAirportCode: String, Codable {
    case dxb = "DXB"
    case ruh = "RUH"
}

// MARK: - Timings
struct Timings: Codable {
    let departure, arrival: [Arrival]

    enum CodingKeys: String, CodingKey {
        case departure = "Departure"
        case arrival = "Arrival"
    }
}

// MARK: - Arrival
struct Arrival: Codable {
    let city, from, to, airportCode: String

    enum CodingKeys: String, CodingKey {
        case city = "City"
        case from = "From"
        case to = "To"
        case airportCode = "AirportCode"
    }
}

// MARK: - Itinerary
struct Itinerary: Codable {
    let iteneraryID, iteneraryTagID: String
    let itenerarySequenceNumber: Int
    let iteneraryTotalFareAmount: Double
    let iteneraryTotalFareCurrency: Currency
    let iteneraryEquivFareAmount: Double
    let iteneraryEquivFareCurrency: Currency
    let iteneraryTotalTaxesAmount: Double
    let iteneraryTotalTaxesCurrency: Currency
    let passengerTypes: [ItineraryPassengerType]
    let iteneraryTripType: ConnectionTypeEnum
    let legs: [String]
    let perPersonEquivFareAmount, perPersonTotalFareAmount, perPersonTotalTaxAmount: Double
    let iteneraryNonRefundableIndicator, finished: Bool
    let totalFareAmountAfterAllCustDiscounts: Double
    let canBookNowPayLater: Bool
    let iteneraryUniqueID: UniqueID
    let iteneraryDiscountFareAmount: Double
    let brandedFaresAvailable: Bool
    let discountAmount, discountPercentage: Int
    let isSpecialOffer: Bool
    let tierPoints: TierPoints
    let isDomestic: Bool
    let serviceFee: ServiceFee
    let isUmrahFlightIncluded: Bool
    let iteneraryBeforeMarkOn: IteneraryBeforeMarkOn
    let iteneraryMarkOn: IteneraryMarkOn

    enum CodingKeys: String, CodingKey {
        case iteneraryID = "IteneraryID"
        case iteneraryTagID = "IteneraryTagID"
        case itenerarySequenceNumber = "ItenerarySequenceNumber"
        case iteneraryTotalFareAmount = "IteneraryTotalFareAmount"
        case iteneraryTotalFareCurrency = "IteneraryTotalFareCurrency"
        case iteneraryEquivFareAmount = "IteneraryEquivFareAmount"
        case iteneraryEquivFareCurrency = "IteneraryEquivFareCurrency"
        case iteneraryTotalTaxesAmount = "IteneraryTotalTaxesAmount"
        case iteneraryTotalTaxesCurrency = "IteneraryTotalTaxesCurrency"
        case passengerTypes = "PassengerTypes"
        case iteneraryTripType = "IteneraryTripType"
        case legs = "Legs"
        case perPersonEquivFareAmount = "PerPersonEquivFareAmount"
        case perPersonTotalFareAmount = "PerPersonTotalFareAmount"
        case perPersonTotalTaxAmount = "PerPersonTotalTaxAmount"
        case iteneraryNonRefundableIndicator = "IteneraryNonRefundableIndicator"
        case finished = "Finished"
        case totalFareAmountAfterAllCustDiscounts = "TotalFareAmountAfterAllCustDiscounts"
        case canBookNowPayLater
        case iteneraryUniqueID = "IteneraryUniqueId"
        case iteneraryDiscountFareAmount = "IteneraryDiscountFareAmount"
        case brandedFaresAvailable, discountAmount, discountPercentage, isSpecialOffer, tierPoints, isDomestic, serviceFee, isUmrahFlightIncluded
        case iteneraryBeforeMarkOn = "IteneraryBeforeMarkOn"
        case iteneraryMarkOn = "IteneraryMarkOn"
    }
}

// MARK: - IteneraryBeforeMarkOn
struct IteneraryBeforeMarkOn: Codable {
    let iteneraryEquivFareAmount, iteneraryTotalFareAmount, perPersonEquivFareAmount, perPersonTotalFareAmount: Double
    let passengerTypes: [IteneraryBeforeMarkOnPassengerType]

    enum CodingKeys: String, CodingKey {
        case iteneraryEquivFareAmount = "IteneraryEquivFareAmount"
        case iteneraryTotalFareAmount = "IteneraryTotalFareAmount"
        case perPersonEquivFareAmount = "PerPersonEquivFareAmount"
        case perPersonTotalFareAmount = "PerPersonTotalFareAmount"
        case passengerTypes = "PassengerTypes"
    }
}

// MARK: - IteneraryBeforeMarkOnPassengerType
struct IteneraryBeforeMarkOnPassengerType: Codable {
    let passengerType: PassengerTypeEnum
    let pxTypeEquivFareAmount, pxTypeTotalTaxAmount, pxTypeTotalFareAmount: Double

    enum CodingKeys: String, CodingKey {
        case passengerType = "PassengerType"
        case pxTypeEquivFareAmount = "PxTypeEquivFareAmount"
        case pxTypeTotalTaxAmount = "PxTypeTotalTaxAmount"
        case pxTypeTotalFareAmount = "PxTypeTotalFareAmount"
    }
}

enum PassengerTypeEnum: String, Codable {
    case adt = "ADT"
    case cnn = "CNN"
    case inf = "INF"
}

enum Currency: String, Codable {
    case sar = "SAR"
}

// MARK: - IteneraryMarkOn
struct IteneraryMarkOn: Codable {
    let markOn, agencyMarkup: Int
    let markOnType: MarkOnType
}

enum MarkOnType: String, Codable {
    case markUp = "MarkUp"
}

enum ConnectionTypeEnum: String, Codable {
    case oneWay = "OneWay"
}

enum UniqueID: String, Codable {
    case xy14Xy1420250608T060500Xy205Xy20520250608T122000 = "XY14XY142025-06-08T06:05:00XY205XY2052025-06-08T12:20:00"
    case xy18Xy1820250608T071500Xy221Xy22120250608T132500 = "XY18XY182025-06-08T07:15:00XY221XY2212025-06-08T13:25:00"
    case xy22Xy2220250608T123000Xy209Xy20920250608T185000 = "XY22XY222025-06-08T12:30:00XY209XY2092025-06-08T18:50:00"
    case xy40Xy4020250608T154000Xy213Xy21320250608T220000 = "XY40XY402025-06-08T15:40:00XY213XY2132025-06-08T22:00:00"
    case xy501Xy50120250608T071000 = "XY501XY5012025-06-08T07:10:00"
    case xy507Xy50720250608T143500 = "XY507XY5072025-06-08T14:35:00"
    case xy509Xy50920250608T165000 = "XY509XY5092025-06-08T16:50:00"
    case xy58Xy5820250608T014000Xy201Xy20120250608T074000 = "XY58XY582025-06-08T01:40:00XY201XY2012025-06-08T07:40:00"
}

// MARK: - ItineraryPassengerType
struct ItineraryPassengerType: Codable {
    let passengerType: PassengerTypeEnum
    let count: Int
    let pxTypeNonRefundableIndicator: Bool
    let pxTypeEquivFareAmount, pxTypeTotalTaxAmount, pxTypeTotalFareAmount: Double
    let pxTypePenalty: [PxTypePenalty]

    enum CodingKeys: String, CodingKey {
        case passengerType = "PassengerType"
        case count = "Count"
        case pxTypeNonRefundableIndicator = "PxTypeNonRefundableIndicator"
        case pxTypeEquivFareAmount = "PxTypeEquivFareAmount"
        case pxTypeTotalTaxAmount = "PxTypeTotalTaxAmount"
        case pxTypeTotalFareAmount = "PxTypeTotalFareAmount"
        case pxTypePenalty = "PxTypePenalty"
    }
}

// MARK: - PxTypePenalty
struct PxTypePenalty: Codable {
    let type: PxTypePenaltyType
    let applicability: Applicability
    let changeable: Bool?
    let amount: Double
    let decimalPlaces: Int
    let currencyCode: Currency
    let refundable: Bool?

    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case applicability = "Applicability"
        case changeable = "Changeable"
        case amount = "Amount"
        case decimalPlaces = "DecimalPlaces"
        case currencyCode = "CurrencyCode"
        case refundable = "Refundable"
    }
}

enum Applicability: String, Codable {
    case after = "After"
    case before = "Before"
}

enum PxTypePenaltyType: String, Codable {
    case exchange = "Exchange"
    case refund = "Refund"
}

// MARK: - ServiceFee
struct ServiceFee: Codable {
    let amount: Int
    let currency: Currency
}

// MARK: - TierPoints
struct TierPoints: Codable {
    let tier1, tier2, tier3, tier4: Int

    enum CodingKeys: String, CodingKey {
        case tier1 = "tier-1"
        case tier2 = "tier-2"
        case tier3 = "tier-3"
        case tier4 = "tier-4"
    }
}

// MARK: - LegValue
struct LegValue: Codable {
    let legID: String
    let segments: [String]
    let legDirectionality: String
    let legPassengerTypes: [LegPassengerType]
    let stops: [Stop]
    let legElapsedTimeIncludingLayoverDurationInMinutes: Int
    let legDepartureDateTime, legArrivalDateTime: String
    let legDepartureAirportCode: Code
    let legArrivalAirportCode: LegArrivalAirportCode
    let legSeatsRemaining, legTotalLayoverDurationInMinutes: Int
    let legCabins: [Cabin]
    let legTotalNoOfStops: Int
    let legUniqueID: UniqueID
    let legAirlinesCodes: [LegValidatingCarrierCode]
    let legValidatingCarrierCode: LegValidatingCarrierCode
    let legValidatingCarrierNewVcxProcess: Bool
    let legValidatingCarrierSettlementMethod: String
    let pxTypeFareConstructionCurrency: PxTypeFareConstructionCurrency
    let supplierPromoCodeApplied: Bool
    let legAirlinesNames, legAirlineLogos: [String]
    let isUmrah: Bool

    enum CodingKeys: String, CodingKey {
        case legID = "LegID"
        case segments = "Segments"
        case legDirectionality = "LegDirectionality"
        case legPassengerTypes = "LegPassengerTypes"
        case stops = "Stops"
        case legElapsedTimeIncludingLayoverDurationInMinutes = "LegElapsedTimeIncludingLayoverDurationInMinutes"
        case legDepartureDateTime = "LegDepartureDateTime"
        case legArrivalDateTime = "LegArrivalDateTime"
        case legDepartureAirportCode = "LegDepartureAirportCode"
        case legArrivalAirportCode = "LegArrivalAirportCode"
        case legSeatsRemaining = "LegSeatsRemaining"
        case legTotalLayoverDurationInMinutes = "LegTotalLayoverDurationInMinutes"
        case legCabins = "LegCabins"
        case legTotalNoOfStops = "LegTotalNoOfStops"
        case legUniqueID = "LegUniqueId"
        case legAirlinesCodes = "LegAirlinesCodes"
        case legValidatingCarrierCode = "LegValidatingCarrierCode"
        case legValidatingCarrierNewVcxProcess = "LegValidatingCarrierNewVcxProcess"
        case legValidatingCarrierSettlementMethod = "LegValidatingCarrierSettlementMethod"
        case pxTypeFareConstructionCurrency = "PxTypeFareConstructionCurrency"
        case supplierPromoCodeApplied
        case legAirlinesNames = "LegAirlinesNames"
        case legAirlineLogos = "LegAirlineLogos"
        case isUmrah
    }
}

enum Cabin: String, Codable {
    case y = "Y"
}

enum Code: String, Codable {
    case jed = "JED"
    case ruh = "RUH"
}

// MARK: - LegPassengerType
struct LegPassengerType: Codable {
    let passengerType: PassengerTypeEnum
    let legPxTypeBaggageInfoProvisionType: IonType
    let legPxTypeBaggageInfoAirlineCode: LegValidatingCarrierCode
    let legPxTypeBaggageInfoAllowance: LegPxTypeBaggageInfoAllowance
    let legPxTypeMessages: [LegPxTypeMessage]
    let legPxTypeCabinBaggageInfoAllowance: LegPxTypeBaggageInfoAllowance

    enum CodingKeys: String, CodingKey {
        case passengerType = "PassengerType"
        case legPxTypeBaggageInfoProvisionType = "LegPxTypeBaggageInfoProvisionType"
        case legPxTypeBaggageInfoAirlineCode = "LegPxTypeBaggageInfoAirlineCode"
        case legPxTypeBaggageInfoAllowance = "LegPxTypeBaggageInfoAllowance"
        case legPxTypeMessages = "LegPxTypeMessages"
        case legPxTypeCabinBaggageInfoAllowance = "LegPxTypeCabinBaggageInfoAllowance"
    }
}

// MARK: - LegPxTypeBaggageInfoAllowance
struct LegPxTypeBaggageInfoAllowance: Codable {
    let pieces: Int
    let unit: PxTypeFareConstructionCurrency
    let weight: Int
    let dimension: Dimension?

    enum CodingKeys: String, CodingKey {
        case pieces = "Pieces"
        case unit = "Unit"
        case weight = "Weight"
        case dimension = "Dimension"
    }
}

enum Dimension: String, Codable {
    case the56X36X23CM = "56 X 36 X 23 CM"
}

enum PxTypeFareConstructionCurrency: String, Codable {
    case kg = "KG"
    case nA = "N/A"
}

enum IonType: String, Codable {
    case a = "A"
}

// MARK: - LegPxTypeMessage
struct LegPxTypeMessage: Codable {
    let failCode: Int
    let info: PxTypeFareConstructionCurrency
    let type: LegPxTypeMessageType
    let airlineCode: LegValidatingCarrierCode

    enum CodingKeys: String, CodingKey {
        case failCode = "FailCode"
        case info = "Info"
        case type = "Type"
        case airlineCode = "AirlineCode"
    }
}

enum LegPxTypeMessageType: String, Codable {
    case n = "N"
}

// MARK: - Stop
struct Stop: Codable {
    let stopNum: Int
    let stopAirport: LegArrivalAirportCode
    let layoverDurationInMinutes: Int

    enum CodingKeys: String, CodingKey {
        case stopNum = "StopNum"
        case stopAirport = "StopAirport"
        case layoverDurationInMinutes = "LayoverDurationInMinutes"
    }
}

// MARK: - Resources
struct Resources: Codable {
    let allicancesLogosURL, logosURL: String
}

// MARK: - Segment
struct Segment: Codable {
    let segmentUniqueID, segmentID, segmentDepartureDateTime, segmentArrivalDateTime: String
    let segmentResBookDesigCode: SegmentFareReferenceEnum
    let segmentFlightNumber, segmentElapsedTime: Int
    let segmentDepartureAirportCode: Code
    let segmentDepartureAirportTerminalID: String
    let segmentArrivalAirportCode: LegArrivalAirportCode
    let segmentArrivalAirportTerminalID: String
    let segmentDepartureTimeZoneGMTOffset, segmentArrivalTimeZoneGMTOffset: Int
    let segmentAircraftTypeCode: String
    let segmentOperatingAirline: LegValidatingCarrierCode
    let segmentOperatingAirlineAllianceCode: String
    let segmentMarketingAirline: LegValidatingCarrierCode
    let segmentMarketingAirlineAllianceCode: String
    let segmentFareReference: SegmentFareReferenceEnum
    let segmentCabin: Cabin
    let segmentMealCode: PxTypeFareConstructionCurrency
    let segmentSeatsRemaining: Int
    let segmentArrivalCountryCode, segmentDepartureCountryCode: Dxb
    let segmentPassengerType: [SegmentPassengerType]
    let segmentOperatingAirlineFlightNumber: Int

    enum CodingKeys: String, CodingKey {
        case segmentUniqueID = "SegmentUniqueId"
        case segmentID = "SegmentID"
        case segmentDepartureDateTime = "SegmentDepartureDateTime"
        case segmentArrivalDateTime = "SegmentArrivalDateTime"
        case segmentResBookDesigCode = "SegmentResBookDesigCode"
        case segmentFlightNumber = "SegmentFlightNumber"
        case segmentElapsedTime = "SegmentElapsedTime"
        case segmentDepartureAirportCode = "SegmentDepartureAirportCode"
        case segmentDepartureAirportTerminalID = "SegmentDepartureAirportTerminalID"
        case segmentArrivalAirportCode = "SegmentArrivalAirportCode"
        case segmentArrivalAirportTerminalID = "SegmentArrivalAirportTerminalID"
        case segmentDepartureTimeZoneGMTOffset = "SegmentDepartureTimeZoneGMTOffset"
        case segmentArrivalTimeZoneGMTOffset = "SegmentArrivalTimeZoneGMTOffset"
        case segmentAircraftTypeCode = "SegmentAircraftTypeCode"
        case segmentOperatingAirline = "SegmentOperatingAirline"
        case segmentOperatingAirlineAllianceCode = "SegmentOperatingAirlineAllianceCode"
        case segmentMarketingAirline = "SegmentMarketingAirline"
        case segmentMarketingAirlineAllianceCode = "SegmentMarketingAirlineAllianceCode"
        case segmentFareReference = "SegmentFareReference"
        case segmentCabin = "SegmentCabin"
        case segmentMealCode = "SegmentMealCode"
        case segmentSeatsRemaining = "SegmentSeatsRemaining"
        case segmentArrivalCountryCode = "SegmentArrivalCountryCode"
        case segmentDepartureCountryCode = "SegmentDepartureCountryCode"
        case segmentPassengerType = "SegmentPassengerType"
        case segmentOperatingAirlineFlightNumber = "SegmentOperatingAirlineFlightNumber"
    }
}

enum Dxb: String, Codable {
    case ae = "AE"
    case sa = "SA"
}

enum SegmentFareReferenceEnum: String, Codable {
    case e4 = "E4"
    case h = "H"
    case u = "U"
}

// MARK: - SegmentPassengerType
struct SegmentPassengerType: Codable {
    let passengerType: PassengerTypeEnum
    let segmentPxTypeBookingCode: SegmentFareReferenceEnum
    let segmentPxTypeCabin: Cabin
    let segmentPxTypeFareBasisCode: SegmentPxTypeFareBasisCode
    let segmentPxTypeMealCode: PxTypeFareConstructionCurrency
    let segmentPxTypeSeatsRemaining: Int

    enum CodingKeys: String, CodingKey {
        case passengerType = "PassengerType"
        case segmentPxTypeBookingCode = "SegmentPxTypeBookingCode"
        case segmentPxTypeCabin = "SegmentPxTypeCabin"
        case segmentPxTypeFareBasisCode = "SegmentPxTypeFareBasisCode"
        case segmentPxTypeMealCode = "SegmentPxTypeMealCode"
        case segmentPxTypeSeatsRemaining = "SegmentPxTypeSeatsRemaining"
    }
}

enum SegmentPxTypeFareBasisCode: String, Codable {
    case e4Od = "E4OD"
    case hfare = "HFARE"
    case hod = "HOD"
    case uod = "UOD"
}

// MARK: - StaticData
struct StaticData: Codable {
    let airlines: Airlines
    let aircrafts: [String: AircraftValue]
    let airports: [String: AirportValue]
    let alliances: Alliances
    let cabins: Cabins
    let countries: Countries
}

// MARK: - AircraftValue
struct AircraftValue: Codable {
    let code, name: String
}

// MARK: - Airlines
struct Airlines: Codable {
    let xy: Xy

    enum CodingKeys: String, CodingKey {
        case xy = "XY"
    }
}

// MARK: - Xy
struct Xy: Codable {
    let code: LegValidatingCarrierCode
    let logo, name: String
}

// MARK: - AirportValue
struct AirportValue: Codable {
    let airportCode: String
    let countryCode: Dxb
    let timeZoneOffset: Int
    let city: City
    let name: String
}

// MARK: - City
struct City: Codable {
    let name: String
}

// MARK: - Alliances
struct Alliances: Codable {
}

// MARK: - Cabins
struct Cabins: Codable {
    let y: AircraftValue

    enum CodingKeys: String, CodingKey {
        case y = "Y"
    }
}

// MARK: - Countries
struct Countries: Codable {
    let ae, sa: AircraftValue

    enum CodingKeys: String, CodingKey {
        case ae = "AE"
        case sa = "SA"
    }
}

// MARK: - Request
struct Request: Codable {
    let requestID: String
    let currency: Currency
    let classType: String
    let connectionType: ConnectionTypeEnum
    let directFlights, flexibleDates: Bool
    let legs: [LegElement]
    let pax: Pax
    let responseVersion: String
    let isTierAvailable: Bool
    let lng, brand: String
    let appliedCoupon: Bool
    let apiVersion, ipAddress, hostName: String
    let countryCodesFromCityCode: CountryCodesFromCityCode
    let promoCode: PromoCode

    enum CodingKeys: String, CodingKey {
        case requestID = "requestId"
        case currency, classType, connectionType, directFlights, flexibleDates, legs, pax, responseVersion, isTierAvailable, lng, brand, appliedCoupon
        case apiVersion, ipAddress, hostName, countryCodesFromCityCode, promoCode
    }
}

// MARK: - CountryCodesFromCityCode
struct CountryCodesFromCityCode: Codable {
    let jed, dxb: Dxb

    enum CodingKeys: String, CodingKey {
        case jed = "JED"
        case dxb = "DXB"
    }
}

// MARK: - LegElement
struct LegElement: Codable {
    let departDateTime: String
    let destinationCode: LegArrivalAirportCode
    let originCode: Code
    let originLocationType, destinationLocationType: IonType
}

// MARK: - Pax
struct Pax: Codable {
    let adult, child, lapInfant, infantOnChair: Int
}

// MARK: - PromoCode
struct PromoCode: Codable {
    let codes: Alliances
    let isCodeApplied: Bool
}

