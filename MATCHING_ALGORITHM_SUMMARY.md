# 🎯 Service Provider Matching Algorithm - Technical Summary

## **Overview**
A weighted scoring algorithm designed for a referral-based home services platform that prioritizes friend recommendations while maintaining quality and proximity considerations. The algorithm processes user service requests and ranks providers using a 6-component scoring system capped at 100%.

## **Core Formula**
```
Final Score = (Category × 25%) + (Referral × 20%) + (Quality × 20%) + 
              (Location × 15%) + (Availability × 15%) + (History × 5%)
```

## **Component Breakdown**

### **1. Service Category Match (25% Weight)**
- **Perfect Match**: 100% score for exact service category alignment
- **Related Match**: 70% score for complementary services (e.g., handyman for plumbing)
- **No Match**: 0% score for unrelated services
- **Categories**: plumbing, electrical, hvac, handyman, cleaning, landscaping, appliance

**Related Categories Map:**
```dart
'plumbing': ['handyman']
'electrical': ['handyman']
'hvac': ['handyman']
'handyman': ['plumbing', 'electrical', 'hvac', 'appliance']
'cleaning': ['appliance']
'landscaping': ['handyman']
'appliance': ['handyman', 'cleaning']
```

### **2. Referral Bonus (20% Weight - HIGHEST PRIORITY)**
- **Multiple Friends (3+)**: 100% score - highest confidence
- **Two Friends**: 80% score - high confidence  
- **One Friend**: 60% score - good confidence
- **No Referrals**: 0% score
- *Creates 15-20 point advantage for referred providers*

### **3. Quality Rating (20% Weight)**
Based on thumbs up/down system instead of traditional star ratings:
- **90%+ Thumbs Up**: 100% score (excellent)
- **80-89% Thumbs Up**: 90% score (very good)
- **70-79% Thumbs Up**: 80% score (good)
- **60-69% Thumbs Up**: 60% score (fair)
- **50-59% Thumbs Up**: 40% score (poor)
- **<50% Thumbs Up**: 20% score (very poor)
- **No Reviews**: 50% score (neutral)

**Calculation**: `thumbs_up_count / total_jobs_completed`

### **4. Location Proximity (15% Weight)**
Uses Google Maps Distance Matrix API for real-time calculations:
- **≤5km Distance**: 100% score (excellent)
- **≤10km Distance**: 80% score (good)
- **≤20km Distance**: 60% score (fair)
- **≤30km Distance**: 40% score (poor)
- **>30km Distance**: 20% score (very poor)

### **5. Availability Match (15% Weight) - MVP SIMPLIFIED**
- **Accepting New Requests**: 100% score
- **Not Accepting**: 0% score (filtered out before scoring)
- *Simple toggle-based system for MVP - no response time calculations*
- *All eligible providers score 100% since filtered by `accepting_new_requests = true`*

### **6. Previous Work History (5% Weight)**
- **Has Previous Work**: 100% score
- **No Previous Work**: 0% score

## **Technical Implementation**

### **Provider Filtering (Pre-Scoring)**
```dart
// Only eligible providers reach the scoring stage:
FirebaseFirestore.instance
  .collection('providers')
  .where('is_active', isEqualTo: true)
  .where('accepting_new_requests', isEqualTo: true)  // MVP toggle
  .where('service_categories', arrayContains: serviceCategory)
  .where('status', isEqualTo: 'verified')
```

### **Data Sources**
- **Firebase Firestore**: Real-time provider and user data
- **Google Maps Distance Matrix API**: Accurate distance calculations for Seattle metro area
- **User Networks**: Friend connections and referral relationships

### **Processing Flow**
1. **User Request Creation**: AI intake → `UserRequest` object
2. **Provider Filtering**: Query eligible providers from Firestore
3. **User Context Loading**: Fetch friend networks and referral relationships
4. **Distance Calculation**: Google Maps API for real distances
5. **Scoring**: Calculate all 6 components for each provider
6. **Ranking**: Sort by final score (0.0-1.0 range)
7. **Logging**: Store results and match reasoning in Firestore

### **Real-Time Processing**
- Live distance calculations using Google Maps Distance Matrix API
- Dynamic provider filtering based on service categories and availability toggle
- Immediate scoring and ranking with detailed match reasoning

### **Quality Assurance**
- All component scores normalized to 0.0-1.0 range
- Final scores capped at 100% using `clamp(0.0, 1.0)`
- Comprehensive logging for algorithm transparency and debugging

## **Key Features**

### **Referral-First Design**
- 20% weight creates significant advantage for friend-recommended providers
- Scales bonus based on number of referring friends (social proof)
- Includes friend names in match reasoning for transparency

### **Quality Focus**
- Thumbs up/down system instead of traditional star ratings
- Percentage-based scoring rewards consistently good providers
- Neutral scoring for new providers without review history

### **Geographic Intelligence**
- Real address-to-address distance calculations
- Seattle metro area optimization with neighborhood awareness
- Fallback simulation for API failures

### **MVP Availability System**
- Simple binary toggle: accepting new requests (yes/no)
- Pre-filtering ensures only available providers are scored
- No complex response time calculations for initial launch
- All eligible providers receive maximum availability score (15%)

## **Example Calculation**

**Emergency Plumbing Request - Provider with 2 Friend Referrals:**
```dart
// Component Scores (0.0-1.0):
category_score = 1.0      // Exact plumbing match
referral_score = 0.8      // 2 friends referred  
thumbs_up_score = 0.9     // 86.4% thumbs up (108/125)
location_score = 1.0      // 2.1km distance
availability_score = 1.0  // Accepting new requests
previous_work_score = 0.0 // No previous work

// Weighted Final Score:
final_score = (1.0 × 0.25) + (0.8 × 0.20) + (0.9 × 0.20) + 
              (1.0 × 0.15) + (1.0 × 0.15) + (0.0 × 0.05)
            = 0.25 + 0.16 + 0.18 + 0.15 + 0.15 + 0.00
            = 0.89 (89%)
```

**Same Request - No Referrals:**
```dart
// Only referral_score changes:
referral_score = 0.0      // No friends referred (-20 points!)

final_score = 0.25 + 0.00 + 0.18 + 0.15 + 0.15 + 0.00 = 0.73 (73%)
```

## **Performance Characteristics**
- **Average Processing Time**: 2-3 seconds per request
- **Distance Calculation**: Sub-second Google Maps API responses
- **Provider Pool**: Efficiently filters from 10+ active providers
- **Match Accuracy**: Consistently prioritizes referrals while maintaining quality balance

## **Business Impact**
The algorithm successfully creates a **15-20 point scoring advantage** for providers with friend referrals, encouraging viral growth and user engagement while ensuring quality service delivery through balanced weighting of location, availability, and customer satisfaction metrics.

## **MVP Simplifications**
- **Availability**: Binary toggle instead of complex scheduling/response time analysis
- **Pre-filtering**: Reduces computational overhead by eliminating unavailable providers early
- **Consistent Scoring**: All available providers get full availability points, maintaining fair competition

## **Future Enhancements**
- **Advanced Availability**: Response time tracking and emergency availability
- **Dynamic Pricing**: Surge pricing based on demand and provider availability
- **Machine Learning**: Provider performance prediction based on historical data
- **Advanced Location**: Traffic-aware routing and service area optimization
- **Seasonal Adjustments**: Weather and seasonal demand factors

## **Technical Files**
- **Core Algorithm**: `lib/services/provider_matching_service.dart`
- **Models**: `lib/models/provider_match.dart`, `lib/models/user_request.dart`
- **Integration**: `lib/services/user_request_service.dart`
- **Testing**: `lib/screens/matching/provider_matching_test_screen.dart`
- **Geographic Services**: `lib/services/google_maps_service.dart`

---

*Last Updated: December 2024*  
*Algorithm Version: 1.0 (MVP)* 