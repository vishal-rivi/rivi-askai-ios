import Foundation

/// Model for Server-Sent Events response data
struct SSEResponse: Decodable {
    let statusCode: Int
    let content: Content
    
    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case content
    }
    
    struct Content: Decodable {
        let message: String
        let entities: [EntityContainer]?
    }
    
    /// Container for flight entity data
    struct EntityContainer: Decodable {
        // Flight entity fields
        let tripDuration: String?
        let preferredAirlines: [String]?
        let notPreferredAirlines: [String]?
        let preferredDepartureTime: [String]?
        let preferredArrivalTime: [String]?
        let preferredReturnTime: [String]?
        let stopsPreference: [String]?
        let preferredFlightDuration: String?
        let preferredLayoverAirportOrCity: [String]?
        let preferredLayoverDuration: String?
        let preferredBaggagePreference: String?
        let checkedBaggageWeightPreference: [String]?
        let flightBudget: String?
        let flightAmenities: [String]?
        let otherFlightPreferences: [String]?
        
        enum CodingKeys: String, CodingKey {
            case tripDuration = "trip_duration"
            case preferredAirlines = "preferred_airlines"
            case notPreferredAirlines = "not_preferred_airlines"
            case preferredDepartureTime = "preferred_departure_time"
            case preferredArrivalTime = "preferred_arrival_time"
            case preferredReturnTime = "preferred_return_time"
            case stopsPreference = "stops_preference"
            case preferredFlightDuration = "preferred_flight_duration"
            case preferredLayoverAirportOrCity = "preferred_layover_airport_or_city"
            case preferredLayoverDuration = "preferred_layover_duration"
            case preferredBaggagePreference = "preferred_baggage_preference"
            case checkedBaggageWeightPreference = "checked_baggage_weight_preference"
            case flightBudget = "flight_budget"
            case flightAmenities = "flight_amenities"
            case otherFlightPreferences = "other_flight_preferences"
        }
    }
}

/// Utility for extracting and processing SSE data
class SSEDataProcessor {
    
    /// Parse raw SSE data string into a structured response
    /// - Parameter sseData: Raw SSE data string
    /// - Returns: Parsed SSE response or nil if parsing fails
    static func parseSSEData(_ sseData: String) -> SSEResponse? {
        // Handle different SSE data formats
        var jsonData: Data?
        
        // Check if the string is in the "Ask AI event: data(...)" format
        if sseData.contains("Ask AI event: data(") {
            // Extract the data part inside quotes
            if let dataStartIndex = sseData.range(of: "data(\"")?.upperBound,
               let dataEndIndex = sseData.range(of: "\")", options: .backwards)?.lowerBound {
                let dataContent = String(sseData[dataStartIndex..<dataEndIndex])
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\\\", with: "\\")
                
                // Now process the inner data content
                if let innerJsonStartIndex = dataContent.range(of: "data: ")?.upperBound {
                    let innerJsonString = String(dataContent[innerJsonStartIndex...])
                    jsonData = innerJsonString.data(using: .utf8)
                } else {
                    // If there's no "data: " prefix in the inner content, try to use the whole dataContent
                    jsonData = dataContent.data(using: .utf8)
                }
            }
        } 
        // Standard "data: {...}" format
        else if let jsonStartIndex = sseData.range(of: "data: ")?.upperBound {
            let jsonString = String(sseData[jsonStartIndex...])
            jsonData = jsonString.data(using: .utf8)
        }
        
        guard let data = jsonData else {
            RiviAskAILogger.logError("Failed to extract JSON from SSE data")
            return nil
        }
        
        do {
            let response = try JSONDecoder().decode(SSEResponse.self, from: data)
            return response
        } catch {
            RiviAskAILogger.logError("Failed to decode SSE response", error: error)
            // Log the raw data for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                RiviAskAILogger.logError("Raw JSON: \(jsonString)")
            }
            return nil
        }
    }
    
    /// Extract chips from a JSON entity dictionary
    /// - Parameters:
    ///   - entity: Dictionary representing a flight entity
    ///   - isFlightMode: Whether to process as flight entity (kept for API compatibility)
    /// - Returns: Set of extracted chips
    static func extractChipsFromJSONEntity(_ entity: [String: Any], isFlightMode: Bool = true) -> Set<String> {
        var chips = Set<String>()
        
        // Log full entity for debugging
        let keys = entity.keys.joined(separator: ", ")
        RiviAskAILogger.log("Entity keys: \(keys)", level: .debug)
        RiviAskAILogger.log("Entity details: \(entity)", level: .debug)
        
        // Process the entity to check for NSNull values vs empty values
        
        // Trip duration - handle both String and NSNull cases
        if let duration = entity["trip_duration"] as? String, !duration.isEmpty {
            chips.insert("Trip duration: \(duration)")
        }
        
        // Preferred airlines - handle array and check for empty strings
        if let airlines = entity["preferred_airlines"] as? [String] {
            for airline in airlines {
                if !airline.isEmpty {
                    chips.insert(airline)
                    RiviAskAILogger.log("Added airline chip: \(airline)", level: .debug)
                }
            }
        }
        
        // Not preferred airlines
        if let notAirlines = entity["not_preferred_airlines"] as? [String], !notAirlines.isEmpty {
            for airline in notAirlines {
                chips.insert("Not \(airline)")
            }
        }
        
        // Departure time
        if let departureTimes = entity["preferred_departure_time"] as? [String] {
            for time in departureTimes {
                if !time.isEmpty {
                    chips.insert("Departure: \(time)")
                    RiviAskAILogger.log("Added departure time chip: Departure: \(time)", level: .debug)
                }
            }
        }
        
        // Arrival time
        if let arrivalTimes = entity["preferred_arrival_time"] as? [String], !arrivalTimes.isEmpty {
            for time in arrivalTimes {
                chips.insert("Arrival: \(time)")
            }
        }
        
        // Return time
        if let returnTimes = entity["preferred_return_time"] as? [String], !returnTimes.isEmpty {
            for time in returnTimes {
                chips.insert("Return: \(time)")
            }
        }
        
        // Stops preference
        if let stops = entity["stops_preference"] as? [String], !stops.isEmpty {
            for stop in stops {
                let stopText = stop == "0" ? "Non-stop" : (stop == "1" ? "1 stop" : "\(stop) stops")
                chips.insert(stopText)
            }
        }
        
        // Flight duration
        if let duration = entity["preferred_flight_duration"] as? String {
            chips.insert("Flight duration: \(duration)")
        }
        
        // Layover airports/cities
        if let layovers = entity["preferred_layover_airport_or_city"] as? [String], !layovers.isEmpty {
            for layover in layovers {
                chips.insert("Layover at \(layover)")
            }
        }
        
        // Layover duration
        if let layoverDuration = entity["preferred_layover_duration"] as? String {
            chips.insert("Layover duration: \(layoverDuration) hours")
        }
        
        // Preferred baggage preference
        if let baggagePref = entity["preferred_baggage_preference"] as? String {
            chips.insert("Baggage: \(baggagePref)")
        }
        
        // Baggage weight
        if let baggageWeights = entity["checked_baggage_weight_preference"] as? [String], !baggageWeights.isEmpty {
            for weight in baggageWeights {
                chips.insert("Baggage weight \(weight)")
            }
        }
        
        // Budget
        if let budget = entity["flight_budget"] as? String {
            chips.insert("Budget: \(budget)")
        }
        
        // Amenities
        if let amenities = entity["flight_amenities"] as? [String] {
            for amenity in amenities {
                if !amenity.isEmpty {
                    chips.insert(amenity)
                    RiviAskAILogger.log("Added amenity chip: \(amenity)", level: .debug)
                }
            }
        }
        
        // Other preferences
        if let preferences = entity["other_flight_preferences"] as? [String], !preferences.isEmpty {
            for preference in preferences {
                chips.insert(preference)
            }
        }
        
        return chips
    }
    
    /// Map flight entities to chips
    /// - Parameter entity: Flight entity from SSE response
    /// - Returns: Set of chip strings
    static func mapFlightEntitiesToChips(entity: SSEResponse.EntityContainer) -> Set<String> {
        var chips = Set<String>()
        
        // Trip duration
        if let duration = entity.tripDuration {
            chips.insert("Trip duration: \(duration)")
        }
        
        // Preferred airlines
        if let airlines = entity.preferredAirlines, !airlines.isEmpty {
            for airline in airlines {
                chips.insert(airline)
            }
        }
        
        // Not preferred airlines
        if let notAirlines = entity.notPreferredAirlines, !notAirlines.isEmpty {
            for airline in notAirlines {
                chips.insert("Not \(airline)")
            }
        }
        
        // Departure time
        if let departureTimes = entity.preferredDepartureTime, !departureTimes.isEmpty {
            for time in departureTimes {
                chips.insert("Departure: \(time)")
            }
        }
        
        // Arrival time
        if let arrivalTimes = entity.preferredArrivalTime, !arrivalTimes.isEmpty {
            for time in arrivalTimes {
                chips.insert("Arrival: \(time)")
            }
        }
        
        // Return time
        if let returnTimes = entity.preferredReturnTime, !returnTimes.isEmpty {
            for time in returnTimes {
                chips.insert("Return: \(time)")
            }
        }
        
        // Stops preference
        if let stops = entity.stopsPreference, !stops.isEmpty {
            for stop in stops {
                let stopText = stop == "0" ? "Non-stop" : (stop == "1" ? "1 stop" : "\(stop) stops")
                chips.insert(stopText)
            }
        }
        
        // Flight duration
        if let duration = entity.preferredFlightDuration {
            chips.insert("Flight duration: \(duration)")
        }
        
        // Layover airports/cities
        if let layovers = entity.preferredLayoverAirportOrCity, !layovers.isEmpty {
            for layover in layovers {
                chips.insert("Layover at \(layover)")
            }
        }
        
        // Layover duration
        if let layoverDuration = entity.preferredLayoverDuration {
            chips.insert("Layover duration: \(layoverDuration) hours")
        }
        
        // Preferred baggage preference
        if let baggagePref = entity.preferredBaggagePreference {
            chips.insert("Baggage: \(baggagePref)")
        }
        
        // Baggage weight
        if let baggageWeights = entity.checkedBaggageWeightPreference, !baggageWeights.isEmpty {
            for weight in baggageWeights {
                chips.insert("Baggage weight \(weight)")
            }
        }
        
        // Budget
        if let budget = entity.flightBudget {
            chips.insert("Budget: \(budget)")
        }
        
        // Amenities
        if let amenities = entity.flightAmenities, !amenities.isEmpty {
            for amenity in amenities {
                chips.insert(amenity)
            }
        }
        
        // Other preferences
        if let preferences = entity.otherFlightPreferences, !preferences.isEmpty {
            for preference in preferences {
                chips.insert(preference)
            }
        }
        
        return chips
    }
    
    /// Process SSE data string and extract chips
    /// - Parameters:
    ///   - sseData: Raw SSE data string
    ///   - isFlightMode: Always true, kept for API compatibility
    /// - Returns: Set of chip strings or empty set if processing fails
    static func extractChipsFromSSEData(_ sseData: String, isFlightMode: Bool = true) -> Set<String> {
        guard let response = parseSSEData(sseData),
              let entities = response.content.entities,
              !entities.isEmpty else {
            return []
        }
        
        // Process the first entity
        let entity = entities[0]
        let chips = mapFlightEntitiesToChips(entity: entity)
        
        // Log the extracted chips
        RiviAskAILogger.log("Extracted flight chips: \(chips.joined(separator: ", "))", level: .info)
        
        return chips
    }
} 
    
