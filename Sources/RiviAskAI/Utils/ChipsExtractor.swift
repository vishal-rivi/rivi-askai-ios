import Foundation

/// Utility for extracting chips from JSON entities
public class ChipsExtractor {
    /// Extract chips from a JSON entity dictionary
    /// - Parameters:
    ///   - entity: Dictionary representing a flight entity
    ///   - isFlightMode: Whether to process as flight entity (kept for API compatibility)
    /// - Returns: Set of extracted chips
    public static func extractChipsFromJSONEntity(_ entity: [String: Any], isFlightMode: Bool = true) -> Set<String> {
        var chips = Set<String>()
        
        // Trip duration - handle both String and NSNull cases
        if let duration = entity["trip_duration"] as? String, !duration.isEmpty {
            chips.insert("Trip duration: \(duration)")
        }
        
        // Preferred airlines - handle array and check for empty strings
        if let airlines = entity["preferred_airlines"] as? [String] {
            for airline in airlines {
                if !airline.isEmpty {
                    chips.insert(airline)
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
                }
            }
        }
        
        // Other preferences
        if let preferences = entity["other_flight_preferences"] as? [String], !preferences.isEmpty {
            for preference in preferences {
                chips.insert(preference)
            }
        }
        
        // Direct chips array (if available)
        if let directChips = entity["chips"] as? [String] {
            for chip in directChips {
                if !chip.isEmpty {
                    chips.insert(chip)
                }
            }
        }
        
        return chips
    }
} 
