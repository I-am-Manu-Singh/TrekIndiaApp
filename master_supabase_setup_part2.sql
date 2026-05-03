-- ==============================================================================
-- MASTER SUPABASE SETUP: PART 2 (TRIPS 16 - 29: MAXIMUM FIDELITY)
-- ==============================================================================
-- RUN THIS AFTER PART 1 TO COMPLETE THE INVENTORY.

DO $$
DECLARE tid UUID;
BEGIN
    -- [16] DAYARA BUGYAL
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, discount_percent, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('DAYARA BUGYAL', 'Uttarakhand', '5 Days', 'Easy', '11,830 ft', 8500, 5, 4.7, 'https://images.unsplash.com/photo-1469334031218-e382a71b716b', 'Adventure Trek', 'Infinite alpine meadows. Perfect for beginners and families.', 
    $iti$[
        {"day":1,"title":"Raithal Arrival","description":"Drive from Dehradun along the Bhagirathi river. Arrive at the base village.","distance":"180km","time":"7h","image":""},
        {"day":2,"title":"Raithal to Gui","description":"A gentle climb through thick oak and maple forests. Gui is a beautiful clearing.","distance":"5km","time":"4h","image":""},
        {"day":3,"title":"Gui to Chilapada","description":"Entering the lower reaches of the massive meadows. Views of Bandarpoonch.","distance":"3km","time":"3h","image":""},
        {"day":4,"title":"Dayara Summit & Return","description":"Explore the vast high altitude meadows. 360-degree views. Return to Gui.","distance":"8km","time":"6h","image":""},
        {"day":5,"title":"Return Dehradun","description":"Descent to Raithal and drive back.","distance":"185km","time":"8h","image":""}
    ]$iti$, 30.85, 78.60, '11,830 ft', '24 km') RETURNING id INTO tid;
    INSERT INTO public.trip_packages (trip_id, name, price, description) VALUES (tid, 'Standard', 8500, 'Shared tent.');

    -- [17] MARKHA VALLEY
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, discount_percent, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('MARKHA VALLEY', 'Ladakh', '8 Days', 'Moderate', '17,060 ft', 16000, 5, 4.6, 'https://images.unsplash.com/photo-1548013146-72479768bada', 'Adventure Trek', 'Canyon trekking with traditional Ladakhi homestays.', 
    $iti$[
        {"day":1,"title":"Leh Arrival","description":"Essential acclimatization.","distance":"0km","time":"24h","image":""},
        {"day":2,"title":"Drive to Chilling","description":"Trek to Skiu. Cross the Zanskar river via trolley.","distance":"8km","time":"4h","image":""},
        {"day":3,"title":"Skiu to Markha","description":"Long walk through the desert canyon. Huge monasteries.","distance":"20km","time":"7h","image":""},
        {"day":4,"title":"Markha to Hankar","description":"View of Kang Yatse peak. High altitude feel.","distance":"11km","time":"6h","image":""},
        {"day":5,"title":"Hankar to Nimaling","description":"Stunning high altitude meadow camp at 15,500 ft.","distance":"9km","time":"5h","image":""},
        {"day":6,"title":"Kongmaru La Pass","description":"Crossing 17,000 ft. Views of Karakoram range.","distance":"12km","time":"8h","image":""},
        {"day":7,"title":"Shang Sumdo to Leh","description":"Final walk and return to the capital.","distance":"10km","time":"4h","image":""},
        {"day":8,"title":"Departure","description":"End.","distance":"0km","time":"1h","image":""}
    ]$iti$, 33.95, 77.40, '17,060 ft', '75 km') RETURNING id INTO tid;
    INSERT INTO public.trip_packages (trip_id, name, price, description) VALUES (tid, 'Homestay Std', 16000, 'Local feel.');

    -- [18] TARSAR MARSAR
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, discount_percent, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('TARSAR MARSAR', 'Kashmir', '7 Days', 'Moderate', '13,200 ft', 14000, 7, 5.0, 'https://images.unsplash.com/photo-1563725547634-11005c2a110a', 'Adventure Trek', 'The twin lakes of Paradise in Kashmir.', 
    $iti$[
        {"day":1,"title":"Srinagar to Aru","description":"Scenic drive to the meadow village of Aru.","distance":"100km","time":"4h","image":""},
        {"day":2,"title":"Aru to Lidderwat","description":"Forest walk along the Lidder river. Camp in pine forest.","distance":"10km","time":"6h","image":""},
        {"day":3,"title":"Lidderwat to Shekwas","description":"Silver fir forest entrance. Valley walk.","distance":"8km","time":"5h","image":""},
        {"day":4,"title":"Tarsar Lake Arrival","description":"Camp right at the edge of the blue sapphire lake.","distance":"5km","time":"4h","image":""},
        {"day":5,"title":"Marsar Lake Hike","description":"Crossing the ridge to see the sister lake Marsar.","distance":"6km","time":"5h","image":""},
        {"day":6,"title":"Return Lidderwat","description":"Descent journey back to pine camps.","distance":"12km","time":"7h","image":""},
        {"day":7,"title":"Srinagar Drop","description":"End of journey.","distance":"110km","time":"5h","image":""}
    ]$iti$, 34.15, 75.15, '13,200 ft', '48 km') RETURNING id INTO tid;
    INSERT INTO public.trip_packages (trip_id, name, price, description) VALUES (tid, 'Lakeside', 14000, 'Standard.');

    -- [19] BALI PASS
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, discount_percent, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('BALI PASS', 'Uttarakhand', '8 Days', 'Hard', '16,207 ft', 17000, 8, 4.8, 'https://images.unsplash.com/photo-1548013146-72479768bada', 'Adventure Trek', 'Technical crossover pass connecting Sankri to Yamunotri.', 
    $iti$[
        {"day":1,"title":"Sankri Arrival","description":"Base briefing.","distance":"0km","time":"1h","image":""},
        {"day":2,"title":"Seema","description":"River walk along Supin.","distance":"12km","time":"6h","image":""},
        {"day":3,"title":"Rainthal","description":"Meadow climb through forest.","distance":"8km","time":"5h","image":""},
        {"day":4,"title":"Odari","description":"High camp preparation.","distance":"6km","time":"5h","image":""},
        {"day":5,"title":"Bali Pass Base","description":"Snow field camping.","distance":"5km","time":"4h","image":""},
        {"day":6,"title":"The Pass Crossing","description":"Steep technical snow climb. Descent to Damini.","distance":"12km","time":"10h","image":""},
        {"day":7,"title":"Yamunotri Temple","description":"Visit the holy shrine.","distance":"8km","time":"6h","image":""},
        {"day":8,"title":"Return Dehradun","description":"End.","distance":"180km","time":"8h","image":""}
    ]$iti$, 31.05, 78.45, '16,207 ft', '60 km') RETURNING id INTO tid;
    INSERT INTO public.trip_packages (trip_id, name, price, description) VALUES (tid, 'Expedition', 17000, 'Standard.');

    -- [20] VAISHNO DEVI
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, discount_percent, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('VAISHNO DEVI', 'J&K', '2 Days', 'Easy', '5,200 ft', 2500, 0, 5.0, 'https://images.unsplash.com/photo-1578926287944-9e0f3a87a6b2', 'Religious Trek', 'Holy pilgrimage to the cave shrine.', 
    $iti$[
        {"day":1,"title":"Arrive Katra","description":"Check-in and registration. Start night trek.","distance":"0km","time":"1h","image":""},
        {"day":2,"title":"Darshan & Return","description":"Holy Darshan at Bhavan.","distance":"28km","time":"12h","image":""}
    ]$iti$, 32.99, 74.95, '5,200 ft', '28 km') RETURNING id INTO tid;

    -- [21] BADRINATH YATRA
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('BADRINATH YATRA', 'Uttarakhand', '3 Days', 'Easy', '10,279 ft', 4000, 4.8, 'https://images.unsplash.com/photo-1627308595229-7830a5c91f9f', 'Religious Trek', 'Sacred abode of Lord Vishnu.', 
    $iti$[
        {"day":1,"title":"Haridwar to Joshimath","description":"Drive through five confluences.","distance":"250km","time":"9h","image":""},
        {"day":2,"title":"Temple Visit","description":"Visit Badrinath and Mana village.","distance":"50km","time":"4h","image":""},
        {"day":3,"title":"Return","description":"End.","distance":"280km","time":"10h","image":""}
    ]$iti$, 30.74, 79.49, '10,279 ft', 'Motorable') RETURNING id INTO tid;

    -- [22] AMARNATH YATRA
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('AMARNATH YATRA', 'J&K', '4 Days', 'Hard', '12,756 ft', 8000, 4.7, 'https://images.unsplash.com/photo-1548013146-72479768bada', 'Religious Trek', 'Pilgrimage to the holy ice lingam.', 
    $iti$[
        {"day":1,"title":"Srinagar to Baltal","description":"Base camp.","distance":"100km","time":"4h","image":""},
        {"day":2,"title":"The Holy Cave","description":"Trek to cave.","distance":"14km","time":"7h","image":""},
        {"day":3,"title":"Return Baltal","description":"Descent.","distance":"14km","time":"6h","image":""},
        {"day":4,"title":"Return Srinagar","description":"End.","distance":"100km","time":"4h","image":""}
    ]$iti$, 34.21, 75.50, '12,756 ft', '28 km') RETURNING id INTO tid;

    -- [23] HEMKUND SAHIB
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('HEMKUND SAHIB', 'Uttarakhand', '4 Days', 'Moderate', '15,200 ft', 6000, 4.8, 'https://images.unsplash.com/photo-1627308595229-7830a5c91f9f', 'Religious Trek', 'Highest Sikh shrine by glacial lake.', 
    $iti$[
        {"day":1,"title":"Govindghat","description":"Start.","distance":"0km","time":"1h","image":""},
        {"day":2,"title":"Ghangaria","description":"Forest walk.","distance":"14km","time":"7h","image":""},
        {"day":3,"title":"Lake Shrine","description":"Steep climb.","distance":"6km","time":"5h","image":""},
        {"day":4,"title":"Return","description":"End.","distance":"20km","time":"8h","image":""}
    ]$iti$, 30.70, 79.61, '15,200 ft', '40 km') RETURNING id INTO tid;

    -- [24] GANGOTRI GAUMUKH
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('GANGOTRI GAUMUKH', 'Uttarakhand', '5 Days', 'Moderate', '12,772 ft', 9000, 4.8, 'https://images.unsplash.com/photo-1627308595229-7830a5c91f9f', 'Religious Trek', 'Trek to source of Ganga.', 
    $iti$[
        {"day":1,"title":"Gangotri","description":"Base.","distance":"0km","time":"1h","image":""},
        {"day":2,"title":"Bhojwassa","description":"River walk.","distance":"14km","time":"6h","image":""},
        {"day":3,"title":"Glacier Witness","description":"Gaumukh ice mouth.","distance":"8km","time":"5h","image":""},
        {"day":4,"title":"Return Bhojwassa","description":"Descent.","distance":"8km","time":"4h","image":""},
        {"day":5,"title":"End","description":"Return.","distance":"14km","time":"6h","image":""}
    ]$iti$, 30.99, 79.06, '12,772 ft', '44 km') RETURNING id INTO tid;

    -- [25] BALI BLISS
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('BALI BLISS', 'Bali', '6 Days', 'Easy', 'Sea Level', 45000, 4.9, 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2', 'Vacation', 'Tropical island escape.', 
    $iti$[
        {"day":1,"title":"Arrival Ubud","description":"Check-in.","distance":"0km","time":"1h","image":""},
        {"day":2,"title":"Rice Terraces","description":"Tour.","distance":"0km","time":"4h","image":""},
        {"day":3,"title":"Jeep Tour","description":"Sunrise.","distance":"0km","time":"5h","image":""},
        {"day":4,"title":"Beach Day","description":"Nusa Penida.","distance":"0km","time":"8h","image":""},
        {"day":5,"title":"Sunset Dinner","description":"Seminyak.","distance":"0km","time":"4h","image":""},
        {"day":6,"title":"Departure","description":"End.","distance":"0km","time":"1h","image":""}
    ]$iti$, -8.41, 115.19, 'Sea Level', 'N/A') RETURNING id INTO tid;

    -- [26] ANDAMAN BLISS
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('ANDAMAN BLISS', 'Andaman', '6 Days', 'Easy', 'Sea Level', 38000, 4.9, 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2', 'Vacation', 'Blue waters escape.', 
    $iti$[
        {"day":1,"title":"Port Blair","description":"Arrival.","distance":"0km","time":"1h","image":""},
        {"day":2,"title":"Havelock","description":"Beach arrival.","distance":"0km","time":"3h","image":""},
        {"day":3,"title":"Elephant Beach","description":"Snorkel.","distance":"0km","time":"6h","image":""},
        {"day":4,"title":"Neil Island","description":"Bridge visit.","distance":"0km","time":"4h","image":""},
        {"day":5,"title":"Return Port Blair","description":"Shopping.","distance":"0km","time":"3h","image":""},
        {"day":6,"title":"Departure","description":"End.","distance":"0km","time":"1h","image":""}
    ]$iti$, 11.74, 92.65, 'Sea Level', 'N/A') RETURNING id INTO tid;

    -- [27] TIRUPATI BALAJI
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('TIRUPATI BALAJI', 'AP', '1 Day', 'Easy', '3,200 ft', 1500, 4.9, 'https://images.unsplash.com/photo-1627308595229-7830a5c91f9f', 'Religious Trek', 'Holy Darshan.', 
    $iti$[{"day":1,"title":"Alipiri","description":"Walk."}]$iti$, 13.62, 79.41, '3,200 ft', '9 km') RETURNING id INTO tid;

    -- [28] SABARIMALA TREK
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('SABARIMALA TREK', 'Kerala', '2 Days', 'Moderate', '4,133 ft', 2000, 4.8, 'https://images.unsplash.com/photo-1548013146-72479768bada', 'Religious Trek', 'Forest shrine.', 
    $iti$[{"day":1,"title":"Pamba","description":"Start."},{"day":2,"title":"Sannidhanam","description":"Darshan."}]$iti$, 9.44, 77.08, '4,133 ft', '18 km') RETURNING id INTO tid;

    -- [29] ROOPKUND SKELETON LAKE
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('ROOPKUND SKELETON LAKE', 'Uttarakhand', '8 Days', 'Hard', '15,750 ft', 14500, 4.9, 'https://images.unsplash.com/photo-1590050860361-ec8f38d38072', 'Adventure Trek', 'Mystery skeleton lake.', 
    $iti$[
        {"day":1,"title":"Lohajung","description":"Start.","distance":"0km","time":"1h","image":""},
        {"day":2,"title":"Didna","description":"Forest walk.","distance":"8km","time":"5h","image":""},
        {"day":3,"title":"Ali Bugyal","description":"Meadow.","distance":"10km","time":"6h","image":""},
        {"day":4,"title":"Bedni Bugyal","description":"Twin.","distance":"5km","time":"3h","image":""},
        {"day":5,"title":"Bhagwabasa","description":"Climb.","distance":"7km","time":"6h","image":""},
        {"day":6,"title":"Summit","description":"Skeletons.","distance":"10km","time":"9h","image":""},
        {"day":7,"title":"Wan Return","description":"Descent.","distance":"15km","time":"8h","image":""},
        {"day":8,"title":"Return","description":"End.","distance":"250km","time":"9h","image":""}
    ]$iti$, 30.26, 79.73, '15,750 ft', '65 km') RETURNING id INTO tid;

END $$;
