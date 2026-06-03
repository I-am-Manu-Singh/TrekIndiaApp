/// Universal Model for all Trip types (Trips, Vacations, Packages, etc.)

class PickupOption {
  final String location;
  final double price;

  PickupOption({required this.location, required this.price});

  factory PickupOption.fromJson(Map<String, dynamic> json) {
    return PickupOption(
      location: (json['location'] ?? '').toString(),
      price: double.tryParse((json['price'] ?? 0.0).toString()) ?? 0.0,
    );
  }
}

class TripPackage {
  final String id;
  final String tripId;
  final String name;
  final double price;
  final String description;
  final List<String> inclusions;
  final bool isActive;

  TripPackage({
    required this.id,
    required this.tripId,
    required this.name,
    required this.price,
    this.description = '',
    this.inclusions = const [],
    this.isActive = true,
  });

  factory TripPackage.fromJson(Map<String, dynamic> json) {
    return TripPackage(
      id: (json['id'] ?? '').toString(),
      tripId: (json['trip_id'] ?? '').toString(),
      name: (json['name'] ?? 'Standard Package').toString(),
      price: double.tryParse((json['price'] ?? 0.0).toString()) ?? 0.0,
      description: (json['description'] ?? '').toString(),
      inclusions: (json['inclusions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      isActive: json['is_active'] ?? true,
    );
  }
}

class TripItinerary {
  final int day;
  final String title;
  final String description;
  final String distance;
  final String time;
  final String imageUrl;

  TripItinerary({
    required this.day,
    required this.title,
    required this.description,
    this.distance = '',
    this.time = '',
    this.imageUrl = '',
  });

  factory TripItinerary.fromJson(Map<String, dynamic> json) {
    return TripItinerary(
      day: json['day'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      distance: json['distance'] ?? '',
      time: json['time'] ?? '',
      imageUrl: json['image'] ?? '',
    );
  }
}

class Trip {
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
  final List<TripItinerary> itinerary;
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
  final List<TripPackage> packages;
  final double? discountedPriceFromDb;
  final String? startPoint;
  final String? packageType;
  final List<DateTime>? availableDates;
  final String? googleMapLink;
  final String? termsConditions;
  final String? cancellationPolicy;
  final String? travelerFormUrl;

  Trip({
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
    this.packages = const [],
    this.discountedPriceFromDb,
    this.startPoint,
    this.packageType,
    this.availableDates,
    this.googleMapLink,
    this.termsConditions,
    this.cancellationPolicy,
    this.travelerFormUrl,
  });

  double get discountedPrice {
    if (discountedPriceFromDb != null && discountedPriceFromDb! > 0 && discountedPriceFromDb! < basePrice) {
      return discountedPriceFromDb!;
    }
    return basePrice * (1 - (discountPercent / 100));
  }

  factory Trip.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Trip.empty();
    
    var itineraryList = (json['itinerary'] as List?)?.map((i) {
      if (i is String) return TripItinerary(day: 0, title: i, description: '');
      return TripItinerary.fromJson(i);
    }).toList() ?? [];

    var pickupList = (json['pickup_options'] as List?)?.map((i) => PickupOption.fromJson(i)).toList() ?? [];
    var pkgsList = (json['trip_packages'] as List?)?.map((i) => TripPackage.fromJson(i)).toList() ?? [];
    
    List<DateTime> batches = [];
    DateTime cursor = DateTime.now().add(const Duration(days: 1));
    while (batches.length < 7) {
      batches.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    
    List<String> parseList(dynamic data) {
      if (data == null) return [];
      if (data is List) return data.map((e) => e.toString()).toList();
      return [];
    }

    return Trip(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled Trip').toString(),
      location: (json['location'] ?? 'Location N/A').toString(),
      duration: (json['duration'] ?? 'N/A').toString(),
      difficulty: (json['difficulty'] ?? 'Moderate').toString(),
      altitude: (json['altitude'] ?? 'N/A').toString(),
      basePrice: double.tryParse((json['base_price'] ?? json['price'] ?? 0.0).toString()) ?? 0.0,
      discountedPriceFromDb: double.tryParse((json['discounted_price'] ?? 0.0).toString()),
      discountPercent: double.tryParse((json['discount_percent'] ?? 0.0).toString()) ?? 0.0,
      rating: double.tryParse((json['rating'] ?? 5.0).toString()) ?? 5.0,
      imageUrl: (json['image_url'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      images: parseList(json['images']),
      itinerary: itineraryList,
      pickupOptions: pickupList,
      inclusions: parseList(json['inclusions']),
      exclusions: parseList(json['exclusions']),
      carryList: parseList(json['carry_list']),
      category: (json['category'] ?? 'Adventure').toString(),
      bestMonths: (json['best_months'] ?? 'All Year').toString(),
      seasonalInfo: json['seasonal_info'] is Map ? Map<String, dynamic>.from(json['seasonal_info']) : {},
      totalDistance: (json['total_distance'] ?? '0 km').toString(),
      latitude: double.tryParse((json['latitude'] ?? '30.7333').toString()) ?? 30.7333,
      longitude: double.tryParse((json['longitude'] ?? '76.7794').toString()) ?? 76.7794,
      peakElevation: (json['peak_elevation'] ?? json['altitude'] ?? 'N/A').toString(),
      trailType: (json['trail_type'] ?? 'Mixed').toString(),
      orientation: (json['orientation'] ?? 'North').toString(),
      packages: pkgsList,
      startPoint: json['start_point']?.toString(),
      packageType: json['package_type']?.toString(),
      googleMapLink: json['google_map_link']?.toString(),
      termsConditions: json['terms_conditions']?.toString(),
      cancellationPolicy: json['cancellation_policy']?.toString(),
      travelerFormUrl: json['traveler_form_url']?.toString(),
    );
  }

  static Trip empty() => Trip(
    id: '', title: 'Loading...', location: '', duration: '', difficulty: '', altitude: '', 
    basePrice: 0, discountPercent: 0, rating: 5, imageUrl: '', description: '',
    discountedPriceFromDb: 0,
  );
}

class Gear {
  final String id;
  final String name;
  final String description;
  final double pricePerDay;
  final double securityDeposit;
  final String category;
  final String imageUrl;
  final int stockCount;

  Gear({
    required this.id,
    required this.name,
    required this.description,
    required this.pricePerDay,
    this.securityDeposit = 500.0,
    this.category = '',
    this.imageUrl = '',
    this.stockCount = 10,
  });

  factory Gear.fromJson(Map<String, dynamic> json) {
    return Gear(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      pricePerDay: double.tryParse(json['price_per_day'].toString()) ?? 0.0,
      securityDeposit: double.tryParse((json['security_deposit'] ?? 500.0).toString()) ?? 500.0,
      category: json['category'] ?? '',
      imageUrl: json['image_url'] ?? '',
      stockCount: int.tryParse((json['stock_count'] ?? 10).toString()) ?? 10,
    );
  }
}

class TripCategory {
  final String id;
  final String name;
  final String? badgeLabel;
  final String? iconName;
  final String? colorHex;
  final bool isSpecial;
  final int displayOrder;

  TripCategory({
    required this.id,
    required this.name,
    this.badgeLabel,
    this.iconName,
    this.colorHex,
    this.isSpecial = false,
    this.displayOrder = 0,
  });

  factory TripCategory.fromJson(Map<String, dynamic> json) {
    return TripCategory(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      badgeLabel: json['badge_label'],
      iconName: json['icon_name'],
      colorHex: json['color_hex'],
      isSpecial: json['is_special'] ?? false,
      displayOrder: json['display_order'] ?? 0,
    );
  }
}
