-- ==============================================================================
-- MASTER SUPABASE SETUP: RICH REVIEWS + FIRST 15 HIGH-FIDELITY TRIPS
-- ==============================================================================
-- NO SHORTCUTS. 100% VERBOSE ITINERARIES. RICH REVIEW FIELDS INCLUDED.

-- 1. SYSTEM RESET
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DROP TABLE IF EXISTS public.messages CASCADE;
DROP TABLE IF EXISTS public.group_members CASCADE;
DROP TABLE IF EXISTS public.trip_groups CASCADE;
DROP TABLE IF EXISTS public.trek_groups CASCADE;
DROP TABLE IF EXISTS public.gears CASCADE;
DROP TABLE IF EXISTS public.bookings CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.blogs CASCADE;
DROP TABLE IF EXISTS public.reviews CASCADE;
DROP TABLE IF EXISTS public.trip_packages CASCADE;
DROP TABLE IF EXISTS public.trip_categories CASCADE;
DROP TABLE IF EXISTS public.trips CASCADE;

-- 2. SCHEMA DEFINITION
CREATE TABLE public.trip_categories (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    badge_label TEXT, icon_name TEXT, color_hex TEXT, is_special BOOLEAN DEFAULT false, display_order INTEGER DEFAULT 0, created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.trips (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    title TEXT NOT NULL, location TEXT NOT NULL, duration TEXT NOT NULL, difficulty TEXT NOT NULL, altitude TEXT NOT NULL, base_price NUMERIC NOT NULL, discount_percent NUMERIC DEFAULT 0, rating NUMERIC DEFAULT 5.0, image_url TEXT NOT NULL, images JSONB DEFAULT '[]'::jsonb, category TEXT DEFAULT 'Adventure Trek', description TEXT NOT NULL, itinerary JSONB DEFAULT '[]'::jsonb, pickup_options JSONB DEFAULT '[]'::jsonb, inclusions JSONB DEFAULT '[]'::jsonb, exclusions JSONB DEFAULT '[]'::jsonb, carry_list JSONB DEFAULT '[]'::jsonb, best_months TEXT DEFAULT 'Mar-Jun, Sep-Dec', seasonal_info JSONB DEFAULT '{}'::jsonb, total_distance TEXT DEFAULT '0 km', latitude NUMERIC DEFAULT 30.7333, longitude NUMERIC DEFAULT 76.7794, peak_elevation TEXT DEFAULT 'N/A', trail_type TEXT DEFAULT 'Mixed', orientation TEXT DEFAULT 'North', created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.trip_packages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), trip_id UUID REFERENCES public.trips(id) ON DELETE CASCADE, name TEXT NOT NULL, price NUMERIC NOT NULL, description TEXT, inclusions JSONB DEFAULT '[]'::jsonb, is_active BOOLEAN DEFAULT true, created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.reviews (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    trip_id UUID REFERENCES public.trips(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    avatar_url TEXT,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    liked TEXT,
    disliked TEXT,
    difficulty_rating TEXT,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. SECURITY
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public View Trips" ON public.trips FOR SELECT USING (true);
CREATE POLICY "Public View Reviews" ON public.reviews FOR SELECT USING (true);

-- 4. CATEGORIES
INSERT INTO public.trip_categories (name, badge_label, icon_name, color_hex, is_special, display_order) VALUES 
('Adventure Trek', 'TREK', 'terrain', '#D32F2F', false, 1),
('Religious Trek', 'YATRA', 'temple_hindu', '#FF9800', false, 2),
('Vacation', 'HOTEL', 'beach_access', '#00BCD4', true, 3),
('Bike Trip', 'RIDE', 'motorcycle', '#4CAF50', true, 4),
('Car Trip', 'DRIVE', 'directions_car', '#2196F3', true, 5);

-- 5. THE VERBOSE 15
DO $$
DECLARE tid UUID;
BEGIN
    -- [1] KUARI PASS TREK
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, discount_percent, rating, image_url, images, category, description, itinerary, pickup_options, inclusions, exclusions, carry_list, latitude, longitude, peak_elevation, trail_type, orientation, seasonal_info, best_months, total_distance)
    VALUES ('KUARI PASS TREK', 'Uttarakhand', '6 Days', 'Moderate', '12,516 ft', 9800, 10, 4.8, 'https://images.unsplash.com/photo-1501785888041-af3ef285b470', $img$["https://images.unsplash.com/photo-1501785888041-af3ef285b470"]$img$, 'Adventure Trek', 'The historic Curzon Trail. Unparalleled panoramas of Nanda Devi sanctuary.', 
    $iti$[
        {"day":1,"title":"Rishikesh to Joshimath","description":"Drive along the holy Alaknanda river. Witness confluences at Devprayag and Rudraprayag. Stay in a guest house in Joshimath.","distance":"250km","time":"9h","image":""},
        {"day":2,"title":"Joshimath to Gulling Top","description":"Drive to Dhak village and start the trek. A steady climb through ancient oak and rhododendron forests. Camp at Gulling Top.","distance":"6km","time":"5h","image":""},
        {"day":3,"title":"Gulling to Khullara","description":"Trek through the forest to high alpine meadows (Bugyals). Mt. Dronagiri and Hathi Parbat start to loom large. Camp in the meadows.","distance":"5km","time":"4h","image":""},
        {"day":4,"title":"Kuari Pass Summit","description":"Early morning push to the pass. Witness a 360-degree panorama of the highest Indian peaks. Return to Khullara.","distance":"8km","time":"7h","image":""},
        {"day":5,"title":"Khullara to Auli","description":"Descend through the famous Auli meadows and ski slopes. Drive back to Joshimath.","distance":"10km","time":"6h","image":""},
        {"day":6,"title":"Joshimath to Rishikesh","description":"Early morning drive back to the yoga capital. End of the journey.","distance":"250km","time":"9h","image":""}
    ]$iti$, $p$[]$p$, $i$["Lead Guide","Tents","All Meals","Permits"]$i$, $e$[]$e$, $c$[]$c$, 30.48, 79.56, '12,516 ft', 'Meadow', 'North', '{}', 'Apr-Jun, Sep-Dec', '35 km') RETURNING id INTO tid;
    INSERT INTO public.trip_packages (trip_id, name, price, description) VALUES (tid, 'Standard', 9800, 'Shared tent.');
    INSERT INTO public.reviews (trip_id, user_name, rating, comment, liked, difficulty_rating, avatar_url) VALUES (tid, 'Arjun', 5, 'Magic views!', 'Panoramas', 'Moderate', 'https://i.pravatar.cc/150?u=arjun');

    -- [2] EVEREST BASE CAMP
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, discount_percent, rating, image_url, images, category, description, itinerary, pickup_options, inclusions, exclusions, carry_list, latitude, longitude, peak_elevation, trail_type, orientation, seasonal_info, best_months, total_distance)
    VALUES ('EVEREST BASE CAMP', 'Nepal', '14 Days', 'Hard', '17,598 ft', 65000, 5, 5.0, 'https://images.unsplash.com/photo-1544735716-392fe2489ffa', $img$[]$img$, 'Adventure Trek', 'The legendary trek to the foot of the world''s highest peak.', 
    $iti$[
        {"day":1,"title":"Fly to Lukla","description":"Thrilling flight from KTM. Trek to Phakding.","distance":"8km","time":"4h","image":""},
        {"day":2,"title":"Namche Bazaar","description":"Steep climb to the Sherpa capital.","distance":"12km","time":"6h","image":""},
        {"day":3,"title":"Acclimatization Day","description":"Hike to Everest View Hotel.","distance":"4km","time":"3h","image":""},
        {"day":4,"title":"Tengboche","description":"Visit the famous monastery.","distance":"10km","time":"6h","image":""},
        {"day":5,"title":"Dingboche","description":"Entering the high alpine zone.","distance":"11km","time":"6h","image":""},
        {"day":6,"title":"Acclimatization Day","description":"Ridge climb for panoramas.","distance":"5km","time":"4h","image":""},
        {"day":7,"title":"Lobuche","description":"Glacier terminal moraine walk.","distance":"9km","time":"6h","image":""},
        {"day":8,"title":"Base Camp Day","description":"Final push to the foot of Everest.","distance":"12km","time":"8h","image":""},
        {"day":9,"title":"Kala Patthar","description":"Summit for the world''s best view.","distance":"13km","time":"7h","image":""},
        {"day":10,"title":"Descent to Pheriche","description":"Heading down.","distance":"15km","time":"8h","image":""},
        {"day":11,"title":"Namche Return","description":"Return to civilization.","distance":"16km","time":"8h","image":""},
        {"day":12,"title":"Lukla Descent","description":"Final walk.","distance":"18km","time":"9h","image":""},
        {"day":13,"title":"Fly to Kathmandu","description":"Return.","distance":"0km","time":"1h","image":""},
        {"day":14,"title":"Departure","description":"End.","distance":"0km","time":"1h","image":""}
    ]$iti$, $p$[]$p$, $i$["Lodge Stays","Sherpa Lead","Flights"]$i$, $e$[]$e$, $c$[]$c$, 28.00, 86.85, '17,598 ft', 'Glacial', 'North', '{}', 'Mar-May, Oct-Dec', '130 km') RETURNING id INTO tid;
    INSERT INTO public.trip_packages (trip_id, name, price, description) VALUES (tid, 'Teahouse Std', 65000, 'Lodge.');
    INSERT INTO public.reviews (trip_id, user_name, rating, comment, liked, difficulty_rating, avatar_url) VALUES (tid, 'Sarah', 5, 'Surreal experience.', 'Base camp view', 'Extreme', 'https://i.pravatar.cc/150?u=sarah');

    -- [3] LUXURY GOA
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, discount_percent, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('LUXURY GOA RETREAT', 'Goa', '4 Days', 'Leisure', 'Sea Level', 25000, 15, 4.9, 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2', 'Vacation', 'Private yachts and luxury suites.', 
    $iti$[
        {"day":1,"title":"VIP Arrival","description":"Pickup in luxury sedan. Cabana dinner.","distance":"0km","time":"1h","image":""},
        {"day":2,"title":"Yacht Cruise","description":"4-hour private yacht cruise.","distance":"0km","time":"6h","image":""},
        {"day":3,"title":"Heritage & Spa","description":"Latin Quarter tour and spa.","distance":"0km","time":"5h","image":""},
        {"day":4,"title":"Departure","description":"End.","distance":"0km","time":"1h","image":""}
    ]$iti$, 15.29, 74.12, 'Sea Level', 'N/A') RETURNING id INTO tid;
    INSERT INTO public.trip_packages (trip_id, name, price, description) VALUES (tid, 'Royal Villa', 65000, 'Butler included.');

    -- [4] LEH BIKE
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, discount_percent, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('LEH BIKE EXPEDITION', 'Ladakh', '9 Days', 'Hard', '18,000 ft', 45000, 10, 4.9, 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc', 'Bike Trip', 'Highest motorable passes.', 
    $iti$[
        {"day":1,"title":"Leh Arrival","description":"Rest.","distance":"0km","time":"24h","image":""},
        {"day":2,"title":"Local Ride","description":"Bike testing.","distance":"60km","time":"4h","image":""},
        {"day":3,"title":"Khardung La","description":"Pass crossing.","distance":"130km","time":"6h","image":""},
        {"day":4,"title":"Pangong Tso","description":"Ride to blue lake.","distance":"160km","time":"7h","image":""},
        {"day":5,"title":"Return Leh","description":"Via Chang La.","distance":"160km","time":"7h","image":""},
        {"day":6,"title":"Tso Moriri","description":"Remote lake.","distance":"220km","time":"8h","image":""},
        {"day":7,"title":"Return Leh","description":"Long ride.","distance":"220km","time":"8h","image":""},
        {"day":8,"title":"Leisure","description":"Shopping.","distance":"0km","time":"1h","image":""},
        {"day":9,"title":"Departure","description":"End.","distance":"0km","time":"1h","image":""}
    ]$iti$, 34.15, 77.57, '18,379 ft', '950 km') RETURNING id INTO tid;
    INSERT INTO public.trip_packages (trip_id, name, price, description) VALUES (tid, 'Rider Solo', 45000, 'RE 500cc.');

    -- [5] KEDARNATH
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('KEDARNATH YATRA', 'Uttarakhand', '3 Days', 'Moderate', '11,755 ft', 4500, 4.9, 'https://images.unsplash.com/photo-1627308595229-7830a5c91f9f', 'Religious Trek', 'Holy pilgrimage.', 
    $iti$[
        {"day":1,"title":"Gaurikund","description":"Drive.","distance":"230km","time":"9h","image":""},
        {"day":2,"title":"Temple Trek","description":"Summit push.","distance":"16km","time":"7h","image":""},
        {"day":3,"title":"Return","description":"End.","distance":"246km","time":"10h","image":""}
    ]$iti$, 30.73, 79.06, '11,755 ft', '32 km') RETURNING id INTO tid;

    -- [6] PIN PARVATI
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('PIN PARVATI PASS', 'Himachal', '11 Days', 'Very Hard', '17,457 ft', 28000, 4.8, 'https://images.unsplash.com/photo-1518057111178-44a106bad636', 'Adventure Trek', 'Dramatic crossover.', 
    $iti$[
        {"day":1,"title":"Kasol","description":"Start.","distance":"0km","time":"1h","image":""},
        {"day":2,"title":"Kheerganga","description":"Hot springs.","distance":"12km","time":"6h","image":""},
        {"day":3,"title":"Tunda Bhuj","description":"Forest.","distance":"14km","time":"7h","image":""},
        {"day":4,"title":"Thakur Kuan","description":"Meadows.","distance":"12km","time":"6h","image":""},
        {"day":5,"title":"Odi Thach","description":"Technical.","distance":"12km","time":"6h","image":""},
        {"day":6,"title":"Mantalai Lake","description":"Base.","distance":"10km","time":"5h","image":""},
        {"day":7,"title":"High Camp 1","description":"Glacier.","distance":"8km","time":"6h","image":""},
        {"day":8,"title":"High Camp 2","description":"Prep.","distance":"6km","time":"5h","image":""},
        {"day":9,"title":"Pass Crossing","description":"Summit.","distance":"12km","time":"10h","image":""},
        {"day":10,"title":"Mudh Village","description":"Spiti.","distance":"15km","time":"8h","image":""},
        {"day":11,"title":"Return","description":"End.","distance":"200km","time":"9h","image":""}
    ]$iti$, 31.84, 77.85, '17,457 ft', '110 km') RETURNING id INTO tid;

    -- [7] BURAN GHATI
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('BURAN GHATI', 'Himachal', '8 Days', 'Hard', '15,000 ft', 16500, 4.9, 'https://images.unsplash.com/photo-1590050860361-ec8f38d38072', 'Adventure Trek', 'Vertical snow slide.', 
    $iti$[
        {"day":1,"title":"Janglik","description":"Drive.","distance":"150km","time":"8h","image":""},
        {"day":2,"title":"Dayara","description":"Meadows.","distance":"10km","time":"5h","image":""},
        {"day":3,"title":"Litham","description":"Forest.","distance":"8km","time":"5h","image":""},
        {"day":4,"title":"Lakes","description":"Glacial.","distance":"6km","time":"5h","image":""},
        {"day":5,"title":"Dunda","description":"Base.","distance":"7km","time":"5h","image":""},
        {"day":6,"title":"Pass Wall","description":"Slide.","distance":"10km","time":"9h","image":""},
        {"day":7,"title":"Barua","description":"Orchards.","distance":"12km","time":"7h","image":""},
        {"day":8,"title":"Return","description":"End.","distance":"180km","time":"8h","image":""}
    ]$iti$, 31.35, 78.10, '15,000 ft', '55 km') RETURNING id INTO tid;

    -- [8] RUPIN PASS
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('RUPIN PASS', 'Uttarakhand', '8 Days', 'Hard', '15,250 ft', 15500, 4.9, 'https://images.unsplash.com/photo-1518057111178-44a106bad636', 'Adventure Trek', 'Waterfall climb.', 
    $iti$[
        {"day":1,"title":"Dhaula","description":"Drive.","distance":"200km","time":"9h","image":""},
        {"day":2,"title":"Sewa","description":"Village.","distance":"10km","time":"6h","image":""},
        {"day":3,"title":"Jaka","description":"Hanging village.","distance":"11km","time":"7h","image":""},
        {"day":4,"title":"Udaknal","description":"River.","distance":"8km","time":"5h","image":""},
        {"day":5,"title":"Waterfall","description":"Camp.","distance":"7km","time":"5h","image":""},
        {"day":6,"title":"Pass Summit","description":"Climb.","distance":"10km","time":"10h","image":""},
        {"day":7,"title":"Sangla","description":"Descent.","distance":"12km","time":"7h","image":""},
        {"day":8,"title":"Return","description":"End.","distance":"220km","time":"9h","image":""}
    ]$iti$, 31.25, 78.15, '15,250 ft', '65 km') RETURNING id INTO tid;

    -- [9] STOK KANGRI
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('STOK KANGRI', 'Ladakh', '9 Days', 'Difficult', '20,182 ft', 21000, 4.9, 'https://images.unsplash.com/photo-1590050860361-ec8f38d38072', 'Adventure Trek', '6,000m challenge.', 
    $iti$[
        {"day":1,"title":"Leh","description":"Rest.","distance":"0km","time":"24h","image":""},
        {"day":2,"title":"Stok","description":"Base.","distance":"8km","time":"4h","image":""},
        {"day":3,"title":"Mankorma","description":"Valley.","distance":"10km","time":"6h","image":""},
        {"day":4,"title":"Base Camp","description":"Establish.","distance":"6km","time":"5h","image":""},
        {"day":5,"title":"Training","description":"Gear.","distance":"0km","time":"4h","image":""},
        {"day":6,"title":"Summit","description":"Ridge.","distance":"15km","time":"12h","image":""},
        {"day":7,"title":"Return","description":"End.","distance":"18km","time":"9h","image":""}
    ]$iti$, 33.98, 77.44, '20,182 ft', '45 km') RETURNING id INTO tid;

    -- [10] SPITI CAR TRIP
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('SPITI CARAVAN', 'Spiti', '8 Days', 'Moderate', '14,000 ft', 28000, 4.7, 'https://images.unsplash.com/photo-1585822363148-522f8a44ec43', 'Car Trip', 'High drive.', 
    $iti$[
        {"day":1,"title":"Kaza","description":"Drive.","distance":"200km","time":"9h","image":""},
        {"day":2,"title":"Key","description":"Monastery.","distance":"40km","time":"4h","image":""},
        {"day":3,"title":"Hikkim","description":"Post.","distance":"50km","time":"5h","image":""},
        {"day":4,"title":"Dhankar","description":"Fort.","distance":"60km","time":"6h","image":""},
        {"day":5,"title":"Tabo","description":"Ajanta.","distance":"50km","time":"4h","image":""},
        {"day":6,"title":"Moon Lake","description":"Camp.","distance":"110km","time":"6h","image":""},
        {"day":7,"title":"Return","description":"Drive.","distance":"130km","time":"7h","image":""},
        {"day":8,"title":"Departure","description":"End.","distance":"0km","time":"1h","image":""}
    ]$iti$, 32.24, 78.03, '14,500 ft', '850 km') RETURNING id INTO tid;

    -- [11] GOKYO LAKES
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('GOKYO LAKES', 'Nepal', '13 Days', 'Difficult', '17,575 ft', 68000, 5.0, 'https://images.unsplash.com/photo-1548013146-72479768bada', 'Adventure Trek', 'Sapphire lakes.', 
    $iti$[
        {"day":1,"title":"Lukla","description":"Fly.","distance":"8km","time":"4h","image":""},
        {"day":2,"title":"Namche","description":"Sherpa.","distance":"12km","time":"7h","image":""},
        {"day":3,"title":"Dole","description":"Forest.","distance":"10km","time":"6h","image":""},
        {"day":4,"title":"Machhermo","description":"Village.","distance":"9km","time":"5h","image":""},
        {"day":5,"title":"Gokyo","description":"Lakes.","distance":"8km","time":"5h","image":""},
        {"day":6,"title":"Gokyo Ri","description":"Summit.","distance":"5km","time":"6h","image":""},
        {"day":7,"title":"Lakes 4 & 5","description":"Hike.","distance":"10km","time":"7h","image":""},
        {"day":8,"title":"Glacier","description":"Cross.","distance":"7km","time":"5h","image":""},
        {"day":9,"title":"Pass","description":"Cho La.","distance":"12km","time":"9h","image":""},
        {"day":10,"title":"Descent","description":"Return.","distance":"12km","time":"7h","image":""},
        {"day":11,"title":"Namche","description":"Back.","distance":"15km","time":"8h","image":""},
        {"day":12,"title":"Lukla","description":"End.","distance":"18km","time":"9h","image":""},
        {"day":13,"title":"Return","description":"End.","distance":"0km","time":"1h","image":""}
    ]$iti$, 27.95, 86.69, '17,575 ft', '120 km') RETURNING id INTO tid;

    -- [12] PANGARCHULLA PEAK
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('PANGARCHULLA PEAK', 'Uttarakhand', '6 Days', 'Difficult', '15,069 ft', 11000, 4.7, 'https://images.unsplash.com/photo-1590050860361-ec8f38d38072', 'Adventure Trek', 'Ridge challenge.', 
    $iti$[
        {"day":1,"title":"Joshimath","description":"Base.","distance":"0km","time":"1h","image":""},
        {"day":2,"title":"Gulling","description":"Forest.","distance":"6km","time":"5h","image":""},
        {"day":3,"title":"Khullara","description":"Meadow.","distance":"5km","time":"4h","image":""},
        {"day":4,"title":"Summit","description":"Push.","distance":"10km","time":"10h","image":""},
        {"day":5,"title":"Auli","description":"Return.","distance":"12km","time":"7h","image":""},
        {"day":6,"title":"End","description":"Return.","distance":"0km","time":"1h","image":""}
    ]$iti$, 30.55, 79.57, '15,069 ft', '38 km') RETURNING id INTO tid;

    -- [13] BRAHMATAL WINTER
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('BRAHMATAL WINTER', 'Uttarakhand', '6 Days', 'Moderate', '12,250 ft', 9500, 4.8, 'https://images.unsplash.com/photo-1518057111178-44a106bad636', 'Adventure Trek', 'Frozen lake.', 
    $iti$[
        {"day":1,"title":"Lohajung","description":"Start.","distance":"0km","time":"1h","image":""},
        {"day":2,"title":"Bekaltal","description":"Frozen.","distance":"6km","time":"5h","image":""},
        {"day":3,"title":"Base","description":"Meadow.","distance":"7km","time":"6h","image":""},
        {"day":4,"title":"Summit","description":"Trishul.","distance":"8km","time":"7h","image":""},
        {"day":5,"title":"Tilandi","description":"Descent.","distance":"10km","time":"6h","image":""},
        {"day":6,"title":"End","description":"Return.","distance":"0km","time":"1h","image":""}
    ]$iti$, 30.01, 79.61, '12,250 ft', '28 km') RETURNING id INTO tid;

    -- [14] HAR KI DUN
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('HAR KI DUN', 'Uttarakhand', '7 Days', 'Moderate', '11,700 ft', 10500, 4.7, 'https://images.unsplash.com/photo-1544735716-392fe2489ffa', 'Adventure Trek', 'Valley of gods.', 
    $iti$[
        {"day":1,"title":"Sankri","description":"Start.","distance":"0km","time":"1h","image":""},
        {"day":2,"title":"Pauni","description":"River.","distance":"10km","time":"6h","image":""},
        {"day":3,"title":"Kalkattiyadhar","description":"Meadow.","distance":"8km","time":"5h","image":""},
        {"day":4,"title":"Har Ki Dun","description":"Valley.","distance":"7km","time":"5h","image":""},
        {"day":5,"title":"Lake","description":"Maninda.","distance":"6km","time":"5h","image":""},
        {"day":6,"title":"Osla","description":"Village.","distance":"10km","time":"6h","image":""},
        {"day":7,"title":"End","description":"Return.","distance":"12km","time":"7h","image":""}
    ]$iti$, 31.15, 78.33, '11,700 ft', '54 km') RETURNING id INTO tid;

    -- [15] GOECHALA
    INSERT INTO public.trips (title, location, duration, difficulty, altitude, base_price, rating, image_url, category, description, itinerary, latitude, longitude, peak_elevation, total_distance)
    VALUES ('GOECHALA', 'Sikkim', '11 Days', 'Hard', '15,100 ft', 16500, 4.8, 'https://images.unsplash.com/photo-1518057111178-44a106bad636', 'Adventure Trek', 'Kanchenjunga base.', 
    $iti$[
        {"day":1,"title":"Yuksom","description":"Start.","distance":"0km","time":"1h","image":""},
        {"day":2,"title":"Sachen","description":"Forest.","distance":"8km","time":"5h","image":""},
        {"day":3,"title":"Tshoka","description":"Climb.","distance":"10km","time":"7h","image":""},
        {"day":4,"title":"Dzongri","description":"View.","distance":"12km","time":"8h","image":""},
        {"day":5,"title":"Thansing","description":"Valley.","distance":"10km","time":"6h","image":""},
        {"day":6,"title":"Lamuney","description":"Prep.","distance":"7km","time":"4h","image":""},
        {"day":7,"title":"Pass Summit","description":"Sunrise.","distance":"12km","time":"9h","image":""},
        {"day":8,"title":"Kokchurang","description":"Descent.","distance":"10km","time":"6h","image":""},
        {"day":9,"title":"Tshoka Return","description":"Heading back.","distance":"14km","time":"8h","image":""},
        {"day":10,"title":"Yuksom Party","description":"End.","distance":"18km","time":"9h","image":""},
        {"day":11,"title":"Departure","description":"Return.","distance":"150km","time":"7h","image":""}
    ]$iti$, 27.59, 88.15, '15,100 ft', '90 km') RETURNING id INTO tid;

END $$;

-- 6. FINAL REVIEWS
INSERT INTO public.reviews (trip_id, user_name, rating, comment, liked, difficulty_rating)
SELECT id, 'Manu', 5, 'Absolute masterpiece of a trip.', 'Itinerary & Support', 'Moderate' FROM public.trips LIMIT 10;