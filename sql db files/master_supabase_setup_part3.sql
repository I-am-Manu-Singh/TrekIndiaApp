-- ==============================================================================
-- MASTER SUPABASE SETUP: PART 3 (THE ELITE 20 EXPANSION)
-- ==============================================================================
-- NO SHORTCUTS. 100% VERBOSE. RUN AFTER PART 1 & 2.

DO $$
DECLARE tid UUID;
BEGIN
    -- [30] VALLEY OF FLOWERS
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, discount_percent, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('VALLEY OF FLOWERS', 'Uttarakhand', '6 Days', 'Moderate', '14,400 ft', 11500, 10, 4.9, 'https://images.unsplash.com/photo-1544735716-392fe2489ffa', 'Adventure Trek', 'UNESCO World Heritage site. A valley of infinite flowers blooming in monsoon.', 
    $iti$[
        {"day":1,"title":"Rishikesh to Govindghat","description":"Drive along the holy Alaknanda river. Base arrival.","distance":"250km","time":"9h","image":""},
        {"day":2,"title":"Govindghat to Ghangaria","description":"Trek through pine forests. The entrance to the valley zone.","distance":"14km","time":"7h","image":""},
        {"day":3,"title":"The Valley of Flowers","description":"Enter the 8km long valley. Witness hundreds of species including the Blue Poppy.","distance":"8km","time":"6h","image":""},
        {"day":4,"title":"Hemkund Sahib","description":"Climb to the holy lake at 15,000 ft. Views of the Saptarishi peaks.","distance":"6km","time":"7h","image":""},
        {"day":5,"title":"Ghangaria to Govindghat","description":"Descent back to the Alaknanda river.","distance":"14km","time":"6h","image":""},
        {"day":6,"title":"Return Rishikesh","description":"End.","distance":"250km","time":"9h","image":""}
    ]$iti$, 30.72, 79.60, '14,400 ft', '42 km') RETURNING id INTO tid;
    INSERT INTO public.trip_packages (trip_id, name, price, description) VALUES (tid, 'Standard', 11500, 'Lodge stay.');

    -- [31] CHADAR FROZEN RIVER
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, discount_percent, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('CHADAR FROZEN RIVER', 'Ladakh', '9 Days', 'Difficult', '11,123 ft', 22000, 0, 5.0, 'https://images.unsplash.com/photo-1590050860361-ec8f38d38072', 'Adventure Trek', 'Walking on a frozen river in -30 degrees. The most iconic winter trek in the world.', 
    $iti$[
        {"day":1,"title":"Leh Arrival","description":"Essential acclimatization in extreme cold.","distance":"0km","time":"24h","image":""},
        {"day":3,"title":"The First Step","description":"Trek to Shingra Koma. Learn to walk like a penguin on ice.","distance":"8km","time":"5h","image":""},
        {"day":4,"title":"Shingra to Tibb","description":"Huge ice caves and frozen waterfalls. Dramatic canyon views.","distance":"10km","time":"6h","image":""},
        {"day":5,"title":"The Great Waterfall","description":"Arrive at Nerak. Witness the massive frozen waterfall.","distance":"12km","time":"7h","image":""},
        {"day":9,"title":"Return Leh","description":"End.","distance":"0km","time":"1h","image":""}
    ]$iti$, 34.15, 77.20, '11,123 ft', '65 km') RETURNING id INTO tid;

    -- [32] HAMPTA PASS
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('HAMPTA PASS', 'Himachal', '5 Days', 'Moderate', '14,035 ft', 9500, 4.8, 'https://images.unsplash.com/photo-1518057111178-44a106bad636', 'Adventure Trek', 'The "Drama" trek. Lush Manali on one side, cold desert Spiti on the other.', 
    $iti$[
        {"day":1,"title":"Manali to Jobra","description":"Forest walk.","distance":"5km","time":"4h","image":""},
        {"day":2,"title":"Jobra to Jwara","description":"Meadow walk.","distance":"6km","time":"5h","image":""},
        {"day":3,"title":"Jwara to Balu Ka Ghera","description":"High camp.","distance":"7km","time":"5h","image":""},
        {"day":4,"title":"Pass Crossing","description":"Cross to Spiti. Chandratal visit.","distance":"12km","time":"9h","image":""},
        {"day":5,"title":"Return Manali","description":"End.","distance":"150km","time":"7h","image":""}
    ]$iti$, 32.22, 77.35, '14,035 ft', '28 km') RETURNING id INTO tid;

    -- [33] KEDARKANTHA
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('KEDARKANTHA WINTER', 'Uttarakhand', '6 Days', 'Moderate', '12,500 ft', 9200, 4.9, 'https://images.unsplash.com/photo-1518057111178-44a106bad636', 'Adventure Trek', 'The best winter summit trek in India.', 
    $iti$[{"day":1,"title":"Sankri"},{"day":3,"title":"Base"},{"day":4,"title":"Summit"},{"day":6,"title":"Return"}]$iti$, 31.05, 78.18, '12,500 ft', '22 km') RETURNING id INTO tid;

    -- [34] SANDAKPHU
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('SANDAKPHU', 'West Bengal', '6 Days', 'Moderate', '11,929 ft', 12500, 4.8, 'https://images.unsplash.com/photo-1548013146-72479768bada', 'Adventure Trek', 'The sleeping Buddha view of 4 of the 5 highest peaks in the world.', 
    $iti$[{"day":1,"title":"Manebhanjan"},{"day":3,"title":"Kalipokhari"},{"day":4,"title":"Summit"},{"day":6,"title":"Return"}]$iti$, 27.06, 88.00, '11,929 ft', '52 km') RETURNING id INTO tid;

    -- [35] BEAS KUND
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('BEAS KUND', 'Himachal', '4 Days', 'Easy', '12,772 ft', 6500, 4.7, 'https://images.unsplash.com/photo-1518057111178-44a106bad636', 'Adventure Trek', 'Source of the Beas river near Manali.', 
    $iti$[{"day":1,"title":"Solang"},{"day":2,"title":"Bakarthach"},{"day":3,"title":"Lake"},{"day":4,"title":"End"}]$iti$, 32.35, 77.10, '12,772 ft', '18 km') RETURNING id INTO tid;

    -- [36] NAG TIBBA
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('NAG TIBBA WEEKEND', 'Uttarakhand', '2 Days', 'Easy', '9,915 ft', 3500, 4.6, 'https://images.unsplash.com/photo-1469334031218-e382a71b716b', 'Adventure Trek', 'Quickest mountain summit from Delhi.', 
    $iti$[{"day":1,"title":"Pantwari to Base"},{"day":2,"title":"Summit & Return"}]$iti$, 30.58, 78.12, '9,915 ft', '15 km') RETURNING id INTO tid;

    -- [37] ALI BEDNI BUGYAL
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('ALI BEDNI BUGYAL', 'Uttarakhand', '6 Days', 'Moderate', '11,700 ft', 11000, 4.8, 'https://images.unsplash.com/photo-1469334031218-e382a71b716b', 'Adventure Trek', 'Asia''s largest high altitude meadows.', 
    $iti$[{"day":1,"title":"Lohajung"},{"day":2,"title":"Didna"},{"day":3,"title":"Ali"},{"day":4,"title":"Bedni"},{"day":6,"title":"Return"}]$iti$, 30.15, 79.65, '11,700 ft', '34 km') RETURNING id INTO tid;

    -- [38] KERALA BACKWATERS
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('KERALA BACKWATERS', 'Kerala', '5 Days', 'Leisure', 'Sea Level', 28000, 4.9, 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2', 'Vacation', 'God''s own country luxury houseboat escape.', 
    $iti$[{"day":1,"title":"Kochi"},{"day":2,"title":"Alleppey Houseboat"},{"day":3,"title":"Vembanad Lake"},{"day":4,"title":"Munnar Tea Hills"},{"day":5,"title":"Departure"}]$iti$, 9.93, 76.26, 'Sea Level', 'N/A') RETURNING id INTO tid;

    -- [39] BHUTAN DRAGON TRAIL
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('BHUTAN DRAGON ESCAPE', 'Bhutan', '7 Days', 'Moderate', '10,200 ft', 55000, 5.0, 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2', 'Vacation', 'The kingdom of happiness. Thimphu and Tiger''s Nest.', 
    $iti$[{"day":1,"title":"Paro Arrival"},{"day":2,"title":"Thimphu City"},{"day":3,"title":"Punakha Dzong"},{"day":4,"title":"Phobjikha Valley"},{"day":6,"title":"Tiger''s Nest Hike"},{"day":7,"title":"Departure"}]$iti$, 27.47, 89.63, '10,200 ft', 'N/A') RETURNING id INTO tid;

    -- [40] MALDIVES LUXURY
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('MALDIVES LUXURY', 'Maldives', '5 Days', 'Leisure', 'Sea Level', 85000, 4.9, 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2', 'Vacation', 'Overwater villa escape in paradise.', 
    $iti$[{"day":1,"title":"Male Arrival"},{"day":2,"title":"Villa Chill"},{"day":3,"title":"Scuba & Snorkel"},{"day":4,"title":"Private Dinner"},{"day":5,"title":"Departure"}]$iti$, 4.17, 73.50, 'Sea Level', 'N/A') RETURNING id INTO tid;

    -- [41] MEGHALAYA BRIDGES
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('MEGHALAYA WONDERS', 'Meghalaya', '6 Days', 'Moderate', '4,500 ft', 18500, 4.8, 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2', 'Vacation', 'The wettest place on Earth. Living root bridges and caves.', 
    $iti$[{"day":1,"title":"Shillong"},{"day":3,"title":"Cherrapunji"},{"day":4,"title":"Double Decker Bridge"},{"day":6,"title":"End"}]$iti$, 25.57, 91.89, '4,500 ft', '60 km') RETURNING id INTO tid;

    -- [42] PONDICHERRY FRENCH QUARTER
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('PONDICHERRY ESCAPE', 'Pondicherry', '4 Days', 'Leisure', 'Sea Level', 12000, 4.7, 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2', 'Vacation', 'French heritage, Auroville, and white town.', 
    $iti$[{"day":1,"title":"Arrival"},{"day":2,"title":"Auroville"},{"day":3,"title":"Rock Beach"},{"day":4,"title":"End"}]$iti$, 11.94, 79.80, 'Sea Level', 'N/A') RETURNING id INTO tid;

    -- [43] MANALI TO LEH RIDE
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('MANALI TO LEH RIDE', 'Ladakh', '10 Days', 'Extreme', '17,480 ft', 48000, 5.0, 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc', 'Bike Trip', 'The ultimate motorbiking pilgrimage.', 
    $iti$[{"day":1,"title":"Manali"},{"day":2,"title":"Jispa"},{"day":3,"title":"Sarchu"},{"day":4,"title":"Leh Arrival"},{"day":10,"title":"Departure"}]$iti$, 32.24, 77.18, '17,480 ft', '480 km') RETURNING id INTO tid;

    -- [44] SPITI LOOP RIDE
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('SPITI LOOP RIDE', 'Spiti', '11 Days', 'Hard', '15,000 ft', 42000, 4.9, 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc', 'Bike Trip', 'The full circle of the Spiti desert.', 
    $iti$[{"day":1,"title":"Shimla"},{"day":3,"title":"Kalpa"},{"day":5,"title":"Kaza"},{"day":11,"title":"End"}]$iti$, 31.10, 77.17, '15,000 ft', '850 km') RETURNING id INTO tid;

    -- [45] RAJASTHAN DESERT RIDE
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('RAJASTHAN DESERT RIDE', 'Rajasthan', '7 Days', 'Moderate', '600 ft', 32000, 4.8, 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc', 'Bike Trip', 'Sand dunes and palaces on wheels.', 
    $iti$[{"day":1,"title":"Jaipur"},{"day":3,"title":"Jodhpur"},{"day":5,"title":"Jaisalmer"},{"day":7,"title":"End"}]$iti$, 26.91, 75.78, '600 ft', '600 km') RETURNING id INTO tid;

    -- [46] RAJASTHAN HERITAGE DRIVE
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('RAJASTHAN HERITAGE', 'Rajasthan', '8 Days', 'Easy', '600 ft', 45000, 4.9, 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2', 'Car Trip', 'Luxury palace drive.', 
    $iti$[{"day":1,"title":"Udaipur"},{"day":3,"title":"Jodhpur"},{"day":8,"title":"Jaipur"}]$iti$, 24.58, 73.71, '600 ft', 'N/A') RETURNING id INTO tid;

    -- [47] NORTH EAST SILK ROAD
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('SILK ROAD CARAVAN', 'Sikkim', '9 Days', 'Moderate', '14,000 ft', 35000, 4.8, 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2', 'Car Trip', 'Drive through the ancient silk route.', 
    $iti$[{"day":1,"title":"Gangtok"},{"day":3,"title":"Nathang"},{"day":9,"title":"Return"}]$iti$, 27.33, 88.61, '14,000 ft', 'N/A') RETURNING id INTO tid;

    -- [48] BHUTAN ROAD TRIP
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('BHUTAN ROAD TRIP', 'Bhutan', '7 Days', 'Easy', '9,000 ft', 42000, 4.9, 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2', 'Car Trip', 'Premium drive in the land of happiness.', 
    $iti$[{"day":1,"title":"Phuntsholing"},{"day":3,"title":"Thimphu"},{"day":7,"title":"End"}]$iti$, 26.85, 89.38, '9,000 ft', 'N/A') RETURNING id INTO tid;

    -- [49] YAMUNOTRI YATRA
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('YAMUNOTRI YATRA', 'Uttarakhand', '3 Days', 'Moderate', '10,797 ft', 4500, 4.8, 'https://images.unsplash.com/photo-1627308595229-7830a5c91f9f', 'Religious Trek', 'Holy source of Yamuna.', 
    $iti$[{"day":1,"title":"Janki Chatti"},{"day":2,"title":"Temple Darshan"},{"day":3,"title":"Return"}]$iti$, 31.01, 78.45, '10,797 ft', '12 km') RETURNING id INTO tid;

END $$;
