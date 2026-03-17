class PickupOption {
  final String location;
  final double price;

  PickupOption({required this.location, required this.price});

  factory PickupOption.fromJson(Map<String, dynamic> json) {
    return PickupOption(
      location: json['location'] ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
    );
  }
}

class TrekItinerary {
  final int day;
  final String title;
  final String description;
  final String distance;
  final String time;
  final String imageUrl;

  TrekItinerary({
    required this.day,
    required this.title,
    required this.description,
    this.distance = '',
    this.time = '',
    this.imageUrl = '',
  });

  factory TrekItinerary.fromJson(Map<String, dynamic> json) {
    return TrekItinerary(
      day: json['day'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      distance: json['distance'] ?? '',
      time: json['time'] ?? '',
      imageUrl: json['image'] ?? '',
    );
  }
}

class Trek {
  final String id;
  final String title;
  final String location;
  final String duration;
  final String difficulty;
  final String altitude;
  final double basePrice;
  final double discountPercent;
  final double rating;
  final String imageUrl;
  final List<String> images;
  final String description;
  final List<TrekItinerary> itinerary;
  final List<PickupOption> pickupOptions;
  final List<String> inclusions;
  final List<String> exclusions;
  final List<String> carryList;
  final String category;
  final String bestMonths;
  final Map<String, dynamic> seasonalInfo;
  final String totalDistance;
  final double latitude;
  final double longitude;
  final String peakElevation;
  final String trailType;
  final String orientation;

  Trek({
    required this.id,
    required this.title,
    required this.location,
    required this.duration,
    required this.difficulty,
    required this.altitude,
    required this.basePrice,
    required this.discountPercent,
    required this.rating,
    required this.imageUrl,
    this.images = const [],
    required this.description,
    this.itinerary = const [],
    this.pickupOptions = const [],
    this.inclusions = const [],
    this.exclusions = const [],
    this.carryList = const [],
    this.category = 'Adventure',
    this.bestMonths = 'Mar-Jun, Sep-Dec',
    this.seasonalInfo = const {},
    this.totalDistance = '0 km',
    this.latitude = 30.7333,
    this.longitude = 76.7794,
    this.peakElevation = 'N/A',
    this.trailType = 'Mixed',
    this.orientation = 'North',
  });

  double get discountedPrice => basePrice * (1 - (discountPercent / 100));

  factory Trek.fromJson(Map<String, dynamic> json) {
    var itineraryList = (json['itinerary'] as List?)?.map((i) {
      if (i is String) return TrekItinerary(day: 0, title: i, description: '');
      return TrekItinerary.fromJson(i);
    }).toList() ?? [];

    var pickupList = (json['pickup_options'] as List?)?.map((i) => PickupOption.fromJson(i)).toList() ?? [];
    
    // Improved list parsing
    List<String> parseList(dynamic data) {
      if (data == null) return [];
      if (data is List) return data.map((e) => e.toString()).toList();
      return [];
    }

    return Trek(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      location: json['location'] ?? '',
      duration: json['duration'] ?? '',
      difficulty: json['difficulty'] ?? '',
      altitude: json['altitude'] ?? '',
      basePrice: double.tryParse((json['base_price'] ?? json['price']).toString()) ?? 0.0,
      discountPercent: double.tryParse(json['discount_percent'].toString()) ?? 0.0,
      rating: double.tryParse(json['rating'].toString()) ?? 5.0,
      imageUrl: json['image_url'] ?? '',
      description: json['description'] ?? '',
      images: parseList(json['images']),
      itinerary: itineraryList,
      pickupOptions: pickupList,
      inclusions: parseList(json['inclusions']),
      exclusions: parseList(json['exclusions']),
      carryList: parseList(json['carry_list']),
      category: json['category'] ?? 'Adventure',
      bestMonths: json['best_months'] ?? 'Mar-Jun, Sep-Dec',
      seasonalInfo: json['seasonal_info'] ?? {},
      totalDistance: json['total_distance'] ?? '0 km',
      latitude: double.tryParse(json['latitude']?.toString() ?? '30.7333') ?? 30.7333,
      longitude: double.tryParse(json['longitude']?.toString() ?? '76.7794') ?? 76.7794,
      peakElevation: json['peak_elevation'] ?? json['altitude'] ?? 'N/A',
      trailType: json['trail_type'] ?? 'Rugged',
      orientation: json['orientation'] ?? 'North-East',
    );
  }
}

class Gear {
  final String id;
  final String name;
  final String description;
  final double pricePerDay;
  final String category;
  final String imageUrl;

  Gear({
    required this.id,
    required this.name,
    required this.description,
    required this.pricePerDay,
    this.category = '',
    this.imageUrl = '',
  });

  factory Gear.fromJson(Map<String, dynamic> json) {
    return Gear(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      pricePerDay: double.tryParse(json['price_per_day'].toString()) ?? 0.0,
      category: json['category'] ?? '',
      imageUrl: json['image_url'] ?? '',
    );
  }
}
