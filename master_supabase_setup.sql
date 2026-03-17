-- 1. ENABLE EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. RESET TABLES (CLEAN SLATE)
DROP TABLE IF EXISTS public.messages CASCADE;
DROP TABLE IF EXISTS public.group_members CASCADE;
DROP TABLE IF EXISTS public.trek_groups CASCADE;
DROP TABLE IF EXISTS public.booking_addons CASCADE;
DROP TABLE IF EXISTS public.gears CASCADE;
DROP TABLE IF EXISTS public.bookings CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.blogs CASCADE;
DROP TABLE IF EXISTS public.reviews CASCADE;  -- add this
DROP TABLE IF EXISTS public.treks CASCADE;
-- ==========================================
-- 3. CREATE TABLES
-- ==========================================

CREATE TABLE public.treks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    title TEXT NOT NULL,
    location TEXT NOT NULL,
    duration TEXT NOT NULL,
    difficulty TEXT NOT NULL,
    altitude TEXT NOT NULL,
    base_price NUMERIC NOT NULL,
    discount_percent NUMERIC DEFAULT 0,
    rating NUMERIC DEFAULT 5.0,
    image_url TEXT NOT NULL,
    category TEXT DEFAULT 'Adventure Trek',
    description TEXT NOT NULL,
    itinerary JSONB DEFAULT '[]'::jsonb,
    pickup_options JSONB DEFAULT '[{"location": "Dehradun", "price": 1500}, {"location": "Rishikesh", "price": 1000}]'::jsonb,
    best_months TEXT DEFAULT 'Mar-Jun, Sep-Dec',
    seasonal_info JSONB DEFAULT '{}'::jsonb, -- {"Jan": "Deep Snow", "Jun": "Rainy", "Oct": "Clear Skies"}
    total_distance TEXT DEFAULT '0 km',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.gears (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    price_per_day NUMERIC NOT NULL,
    image_url TEXT,
    category TEXT
);

CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    full_name TEXT,
    role TEXT DEFAULT 'user' CHECK (role IN ('user','admin','leader')),
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.trek_groups (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    trek_id UUID REFERENCES public.treks(id) ON DELETE CASCADE,
    departure_date DATE NOT NULL,
    group_name TEXT,
    status TEXT DEFAULT 'Open'
);

CREATE TABLE public.bookings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    trek_id UUID REFERENCES public.treks(id) ON DELETE CASCADE,
    group_id UUID REFERENCES public.trek_groups(id) ON DELETE SET NULL,
    travelers INTEGER DEFAULT 1,
    trek_date DATE NOT NULL,
    pickup_location TEXT,
    trek_price NUMERIC NOT NULL,
    pickup_price NUMERIC DEFAULT 0,
    total_price NUMERIC NOT NULL,
    payment_status TEXT DEFAULT 'Pending',
    payment_method TEXT DEFAULT 'UPI',
    status TEXT DEFAULT 'Confirmed',
    booking_date TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.booking_addons (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    booking_id UUID REFERENCES public.bookings(id) ON DELETE CASCADE,
    gear_id UUID REFERENCES public.gears(id) ON DELETE CASCADE,
    quantity INTEGER DEFAULT 1,
    price_at_booking NUMERIC NOT NULL
);

CREATE TABLE public.messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    room_id UUID NOT NULL, 
    sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_group_chat BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.blogs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    read_time TEXT,
    content TEXT NOT NULL,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE TABLE public.reviews (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    trek_id UUID REFERENCES public.treks(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    liked TEXT,
    disliked TEXT,
    difficulty_rating TEXT,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- SECURITY (RLS)
ALTER TABLE public.treks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gears ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blogs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trek_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_view_treks" ON public.treks FOR SELECT USING (true);
CREATE POLICY "public_view_gears" ON public.gears FOR SELECT USING (true);
CREATE POLICY "public_view_blogs" ON public.blogs FOR SELECT USING (true);
CREATE POLICY "public_view_profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "public_view_groups" ON public.trek_groups FOR SELECT USING (true);
CREATE POLICY "insert_groups" ON public.trek_groups FOR INSERT WITH CHECK (true);
CREATE POLICY "booking_access" ON public.bookings FOR ALL USING (true);
CREATE POLICY "addon_access" ON public.booking_addons FOR ALL USING (true);
CREATE POLICY "message_access" ON public.messages FOR ALL USING (true);
CREATE POLICY "public_view_reviews" ON public.reviews FOR SELECT USING (true);
CREATE POLICY "admin_all_gears" ON public.gears FOR ALL USING (true);
-- AUTOMATED PROFILE CREATION
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, avatar_url, role)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'avatar_url', 'user');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ==========================================
-- 6. FULL SEED DATA (25+ TREKS & 15+ BLOGS)
-- ==========================================

-- GEARS/RENTALS
INSERT INTO public.gears (name, description, price_per_day, category, image_url) VALUES
('Trekking Pole', 'Carbon fiber lightweight poles', 100, 'Essential', 'https://images.unsplash.com/photo-1596751303335-742b5048f176'),
('Rucksack 60L', 'Large capacity with rain cover', 250, 'Backpacks', 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62'),
('Down Jacket', 'Insulated for -10 degrees', 300, 'Clothing', 'https://images.unsplash.com/photo-1544531585-9837bd664d93'),
('Trekking Shoes', 'High ankle grip shoes', 200, 'Footwear', 'https://images.unsplash.com/photo-1542291026-7eec264c27ff'),
('Headlamp', '150 lumens LED lamp', 50, 'Electronics', 'https://images.unsplash.com/photo-1507206130118-b5907f817163'),
('Sleeping Bag', 'Mountain grade -5C bag', 150, 'Sleep', 'https://images.unsplash.com/photo-1518057111178-44a106bad636'),
('Rain Poncho', 'Universal size waterproof', 80, 'Clothing', 'https://images.unsplash.com/photo-1531317500508-36423c5e8992'),
('Gaiters', 'Snow and mud protection', 70, 'Accessories', 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b'),
('Gloves', 'Inner fleece + outer waterproof', 60, 'Clothing', 'https://images.unsplash.com/photo-1541600391513-3ec95fa11096'),
('Thermal Set', 'Base layer top and bottom', 120, 'Clothing', 'https://images.unsplash.com/photo-1582738412120-7f4de749ca24');

INSERT INTO public.blogs (title, author, read_time, content, image_url) VALUES

(
'Preparation for Himalayan Trekking',
'Experts',
'6 min',
'Trekking in the Himalayas requires more than enthusiasm and a good pair of shoes. The high altitude, unpredictable weather, and long walking hours demand both physical and mental preparation. The best way to prepare is to begin training at least four weeks before the trek. Focus on building cardiovascular endurance through jogging, brisk walking, cycling, or stair climbing. Strength training is equally important because strong legs and a stable core reduce fatigue during steep climbs and descents. Squats, lunges, and planks should become part of your routine. Hydration and nutrition also play a major role. Eat balanced meals rich in protein and complex carbohydrates while gradually increasing daily activity levels. Another important aspect is gear familiarity. Always test your backpack, trekking shoes, and clothing layers during practice hikes. The mountains reward preparation, and those who train beforehand enjoy the journey far more than those who struggle with basic fitness.',
'https://images.unsplash.com/photo-1522199755839-a2bacb67c546'
),

(
'Essential Gear Checklist',
'Anita Desai',
'7 min',
'Having the right gear can make the difference between a comfortable trek and a miserable one. The most essential item is a sturdy pair of trekking shoes with ankle support and good grip. Blisters and foot injuries are among the most common problems on long treks, so investing in quality footwear is crucial. Layered clothing is equally important because mountain weather changes quickly. A moisture-wicking base layer, an insulating mid layer, and a waterproof outer jacket help regulate body temperature in varying conditions. Other essential items include a durable backpack with a rain cover, a reusable water bottle, a headlamp, trekking poles, sunscreen, sunglasses, and gloves. A compact first aid kit with bandages, antiseptic cream, and altitude medication should always be carried. Finally, pack light but smart. The goal is to carry only what you need while ensuring you are prepared for cold nights, sudden rain, and long walking days.',
'https://images.unsplash.com/photo-1515444744559-7be63e1600de'
),

(
'Winter Treks in India',
'Rahul Sharma',
'5 min',
'Winter transforms the Himalayas into a breathtaking landscape of snow-covered forests and frozen lakes. Treks like Kedarkantha and Brahmatal become especially popular during this season because they offer accessible summit views without requiring extreme technical skills. Snow trekking introduces a different challenge compared to summer trails. Walking on packed snow requires careful footing and sometimes the use of microspikes or gaiters. However, the reward is worth the effort. The forests appear magical under fresh snow, and sunrise views from high ridges reveal vast Himalayan peaks glowing golden in the morning light. Winter treks also tend to be quieter than summer expeditions, allowing trekkers to experience the serenity of the mountains. For those who want their first experience of snow trekking, India offers several beginner-friendly winter routes that combine adventure with unforgettable scenery.',
'https://images.unsplash.com/photo-1501785888041-af3ef285b470'
),

(
'Altitude Sickness Guide',
'Dr. Arjun',
'6 min',
'Altitude sickness is one of the most common challenges faced by trekkers in the Himalayas. As elevation increases, the amount of oxygen in the air decreases, which can cause symptoms such as headache, nausea, dizziness, and fatigue. The best way to prevent altitude sickness is gradual acclimatization. Trekkers should avoid gaining more than 500 meters of sleeping altitude per day once they cross 3000 meters. Drinking plenty of water, eating balanced meals, and maintaining a slow walking pace also help the body adjust to thinner air. It is important to recognize early warning signs and never ignore symptoms. Resting, descending to lower altitude, or seeking medical help may be necessary in severe cases. Trek leaders often carry oxygen cylinders and medication for emergencies, but prevention remains the most effective strategy. With proper acclimatization and awareness, most trekkers can safely enjoy high altitude adventures.',
'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee'
),

(
'Kashmir Great Lakes Beauty',
'Editorial',
'6 min',
'The Kashmir Great Lakes trek is widely regarded as one of the most beautiful alpine treks in the world. Located in the heart of the Kashmir valley, the trail passes through vast meadows, high mountain passes, and a chain of pristine glacial lakes. Each lake has a unique shade of blue or green, reflecting the surrounding snow-covered peaks. During summer, the meadows burst into life with colorful wildflowers that stretch across the landscape. Trekkers often describe waking up beside these lakes as one of the most magical experiences in the Himalayas. The journey is physically demanding but incredibly rewarding. From the first glimpse of Vishansar Lake to the final views of Gangabal beneath Mount Harmukh, every day on the trail reveals a new landscape that feels almost unreal.',
'https://images.unsplash.com/photo-1595844730298-b960fad9fb00'
),

(
'Weekend Treks for Beginners',
'Guides',
'5 min',
'Not everyone has the time for long expeditions, which is why weekend treks have become increasingly popular among city travelers. These short adventures allow people to escape urban life and experience nature without taking extended time off work. Treks like Triund in Himachal Pradesh or Nag Tibba near Mussoorie offer stunning mountain views while remaining accessible to beginners. The trails are relatively short and can be completed within one or two days. Weekend treks are ideal for learning the basics of trekking, including backpack packing, trail navigation, and campsite etiquette. For many people, these small adventures become the first step toward larger Himalayan expeditions. Once someone experiences their first sunrise in the mountains, it often inspires them to return again and again.',
'https://images.unsplash.com/photo-1589146197349-8fb3d1e1f987'
),

(
'Mountain Photography',
'Rohan',
'6 min',
'Capturing the beauty of the mountains requires patience, timing, and an understanding of natural light. The best photographs are often taken during the early morning or late evening when sunlight creates dramatic shadows and golden tones. Wide angle lenses are ideal for landscape photography because they allow photographers to capture vast mountain ranges and expansive valleys. Composition is equally important. Including elements such as trekking trails, rivers, or tents can add depth and storytelling to the image. Weather conditions also influence photography. Misty mornings can create a mysterious atmosphere, while clear skies reveal distant peaks in stunning detail. For trekkers who love photography, the Himalayas provide endless opportunities to capture moments that few places on Earth can match.',
'https://images.unsplash.com/photo-1469474968028-56623f02e42e'
),

(
'Sustainable Trekking',
'Meera',
'6 min',
'Sustainable trekking is essential to protect the fragile ecosystems of mountain regions. As trekking becomes more popular, increased foot traffic can lead to litter, damaged trails, and disturbed wildlife habitats. Responsible trekkers follow simple principles to minimize their environmental impact. Always carry back all non-biodegradable waste, avoid using single-use plastics, and stay on marked trails. Respect local communities by supporting small homestays and local guides whenever possible. Water sources should be kept clean by avoiding soap or chemical contamination. Sustainable trekking is not only about protecting nature but also about ensuring that future generations can enjoy the same breathtaking landscapes. Every trekker shares the responsibility of preserving these mountains.',
'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee'
),

(
'Trekking Safety Tips',
'Safety Team',
'5 min',
'Safety should always be the top priority on any trekking expedition. Before starting a trek, inform family members or local authorities about your planned route and expected return date. Weather conditions in the mountains can change rapidly, so always check forecasts and be prepared for sudden rain or snow. Carrying a basic first aid kit, extra food, and a reliable navigation tool such as a GPS device or offline maps can be extremely helpful in emergencies. Trekking in groups is generally safer than trekking alone, especially in remote regions. Finally, listen to your body. Fatigue, dehydration, or altitude sickness should never be ignored. Turning back is always better than risking serious injury in harsh terrain.',
'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee'
);
-- TREKS (25+ WITH RICH ITINERARIES)
INSERT INTO public.treks (title, location, duration, difficulty, altitude, base_price, discount_percent, image_url, description, category, itinerary, seasonal_info, total_distance
) VALUES
(
'Kuari Pass Trek',
'Uttarakhand, India',
'6 Days',
'Moderate',
'12,516 ft',
9800,
10,
'https://images.unsplash.com/photo-1501785888041-af3ef285b470',
'Historic Lord Curzon trail offering stunning Himalayan panoramas of Nanda Devi and Dronagiri.',
'Adventure Trek',
'[
{"day":1,"title":"Rishikesh to Joshimath","description":"Scenic mountain drive along Alaknanda river.","distance":"250km","time":"9h"},
{"day":2,"title":"Joshimath to Gulling","description":"Drive to Dhak village then trek through oak forests.","distance":"5km","time":"4h"},
{"day":3,"title":"Gulling to Khullara","description":"Climb gradually through rhododendron forests.","distance":"6km","time":"5h"},
{"day":4,"title":"Kuari Pass Summit","description":"Early morning summit for Nanda Devi views.","distance":"8km","time":"7h"},
{"day":5,"title":"Khullara to Auli","description":"Descend through alpine meadows.","distance":"6km","time":"5h"},
{"day":6,"title":"Auli to Rishikesh","description":"Return drive.","distance":"250km","time":"9h"}
]'::jsonb,
'{"Apr":"Blooming Rhododendrons","Oct":"Crystal Clear Himalayan Views","Dec":"Snow Trekking"}'::jsonb,
'31 km'
),

(
'Gaumukh Tapovan Trek',
'Uttarakhand, India',
'8 Days',
'Difficult',
'14,640 ft',
14500,
8,
'https://images.unsplash.com/photo-1501785888041-af3ef285b470',
'Trek to the source glacier of the holy Ganges river and the high altitude meadows of Tapovan.',
'Adventure Trek',
'[
{"day":1,"title":"Dehradun to Gangotri","description":"Drive along Bhagirathi river valley.","distance":"240km","time":"9h"},
{"day":2,"title":"Gangotri to Chirbasa","description":"Trek along pine forests and river cliffs.","distance":"9km","time":"5h"},
{"day":3,"title":"Chirbasa to Bhojbasa","description":"Trek across barren Himalayan valley.","distance":"5km","time":"3h"},
{"day":4,"title":"Gaumukh Glacier","description":"Visit the glacier snout of river Ganga.","distance":"6km","time":"4h"},
{"day":5,"title":"Tapovan Meadows","description":"Steep climb to high altitude alpine meadows.","distance":"3km","time":"4h"},
{"day":6,"title":"Tapovan Exploration","description":"Views of Shivling and Meru peaks.","distance":"3km","time":"3h"},
{"day":7,"title":"Return to Gangotri","description":"Descend through Bhojbasa and Chirbasa.","distance":"14km","time":"7h"},
{"day":8,"title":"Drive to Dehradun","description":"Return journey.","distance":"240km","time":"9h"}
]'::jsonb,
'{"May":"Snow Peaks","Jun":"Clear Glacier Views","Sep":"Best Weather Window"}'::jsonb,
'40 km'
),

(
'Pin Parvati Pass Trek',
'Himachal Pradesh, India',
'11 Days',
'Very Difficult',
'17,457 ft',
28000,
5,
'https://images.unsplash.com/photo-1518057111178-44a106bad636',
'One of the most dramatic Himalayan crossover treks between lush Parvati valley and the barren Spiti landscape.',
'Adventure Trek',
'[
{"day":1,"title":"Kasol Arrival","description":"Orientation and preparation.","distance":"0km","time":"0h"},
{"day":2,"title":"Kasol to Kheerganga","description":"Trek through forest trails and hot springs.","distance":"12km","time":"6h"},
{"day":3,"title":"Kheerganga to Tunda Bhuj","description":"Gradual ascent through alpine valleys.","distance":"10km","time":"7h"},
{"day":4,"title":"Tunda Bhuj to Thakur Kuan","description":"River crossings and glacier views.","distance":"9km","time":"6h"},
{"day":5,"title":"Thakur Kuan to Odi Thach","description":"High altitude campsite.","distance":"7km","time":"5h"},
{"day":6,"title":"Odi Thach to Base Camp","description":"Approach to Pin Parvati glacier.","distance":"6km","time":"5h"},
{"day":7,"title":"Pin Parvati Pass Summit","description":"Technical glacier crossing.","distance":"12km","time":"10h"},
{"day":8,"title":"Manttalai Camp","description":"High altitude desert landscape.","distance":"8km","time":"6h"},
{"day":9,"title":"Manttalai to Mudh Village","description":"Enter Spiti valley.","distance":"15km","time":"7h"},
{"day":10,"title":"Rest and Explore Mudh","description":"Local village culture.","distance":"0km","time":"0h"},
{"day":11,"title":"Drive to Manali","description":"Return through Rohtang Pass.","distance":"190km","time":"8h"}
]'::jsonb,
'{"Jul":"Snow Crossing","Aug":"Stable Weather","Sep":"Clear Spiti Landscapes"}'::jsonb,
'79 km'
),

(
'Stok Kangri Trek',
'Ladakh, India',
'9 Days',
'Very Difficult',
'20,182 ft',
21000,
5,
'https://images.unsplash.com/photo-1590050860361-ec8f38d38072',
'High altitude trekking peak near Leh offering a challenging Himalayan summit.',
'Adventure Trek',
'[
{"day":1,"title":"Arrival Leh","description":"Acclimatization day.","distance":"0km","time":"0h"},
{"day":2,"title":"Leh Exploration","description":"Visit monasteries and markets.","distance":"0km","time":"0h"},
{"day":3,"title":"Leh to Chang Ma","description":"Drive then trek to base camp.","distance":"6km","time":"4h"},
{"day":4,"title":"Chang Ma to Mankorma","description":"Gradual ascent in barren valley.","distance":"5km","time":"4h"},
{"day":5,"title":"Mankorma to Base Camp","description":"Prepare for summit push.","distance":"4km","time":"3h"},
{"day":6,"title":"Summit Attempt","description":"Midnight climb to summit ridge.","distance":"12km","time":"12h"},
{"day":7,"title":"Return to Base Camp","description":"Recovery day.","distance":"6km","time":"5h"},
{"day":8,"title":"Return to Leh","description":"Drive back.","distance":"15km","time":"6h"},
{"day":9,"title":"Departure","description":"Trip ends.","distance":"0km","time":"0h"}
]'::jsonb,
'{"Jul":"Climbing Season","Aug":"Clear Weather","Sep":"Cold Nights"}'::jsonb,
'48 km'
),

(
'Gokyo Lakes Trek',
'Nepal',
'13 Days',
'Difficult',
'17,575 ft',
68000,
8,
'https://images.unsplash.com/photo-1548013146-72479768bada',
'Alternative Everest region trek visiting stunning turquoise glacial lakes.',
'International Trek',
'[
{"day":1,"title":"Kathmandu Arrival","description":"Preparation and briefing.","distance":"0km","time":"0h"},
{"day":2,"title":"Fly to Lukla","description":"Short scenic flight.","distance":"138km","time":"40m"},
{"day":3,"title":"Lukla to Phakding","description":"Walk along Dudh Koshi river.","distance":"8km","time":"4h"},
{"day":4,"title":"Phakding to Namche Bazaar","description":"Climb to Sherpa capital.","distance":"10km","time":"6h"},
{"day":5,"title":"Acclimatization Day","description":"Everest view hike.","distance":"4km","time":"3h"},
{"day":6,"title":"Namche to Dole","description":"Trail through rhododendron forests.","distance":"11km","time":"6h"},
{"day":7,"title":"Dole to Machhermo","description":"High altitude valley trek.","distance":"8km","time":"5h"},
{"day":8,"title":"Machhermo to Gokyo","description":"Reach first glacial lake.","distance":"7km","time":"5h"},
{"day":9,"title":"Gokyo Ri Summit","description":"Panoramic Everest views.","distance":"4km","time":"3h"},
{"day":10,"title":"Return to Dole","description":"Descend valley.","distance":"11km","time":"6h"},
{"day":11,"title":"Return to Namche","description":"Sherpa villages.","distance":"10km","time":"6h"},
{"day":12,"title":"Namche to Lukla","description":"Final trek.","distance":"15km","time":"7h"},
{"day":13,"title":"Fly to Kathmandu","description":"End of trek.","distance":"138km","time":"40m"}
]'::jsonb,
'{"Apr":"Spring Climbing Season","May":"Best Visibility","Oct":"Autumn Clarity"}'::jsonb,
'98 km'
),
(
    'Pangarchulla Peak', 'Uttarakhand, India', '6 Days', 'Difficult', '15,069 ft', 11000, 5, 'https://images.unsplash.com/photo-1590050860361-ec8f38d38072', 
    'Technical summit push.', 'Adventure Trek',
    '[{"day":1,"title":"Joshimath","description":"Briefing.","distance":"0km","time":"2h"}]'::jsonb,
    '{"Apr": "Summit Snow Wall", "May": "Rocky Peak Ascent"}'::jsonb,
    '38 km'
),
(
'Pangarchulla Peak Trek',
'Uttarakhand, India',
'6 Days',
'Difficult',
'15,069 ft',
11000,
5,
'https://images.unsplash.com/photo-1590050860361-ec8f38d38072',
'Technical Himalayan summit trek with snow slopes and massive views of Nanda Devi and Dronagiri.',
'Adventure Trek',
'[
{"day":1,"title":"Rishikesh to Joshimath","description":"Drive through Devprayag and Rudraprayag valleys.","distance":"255km","time":"9h"},
{"day":2,"title":"Joshimath to Gulling","description":"Drive to Dhak then trek through oak forest.","distance":"5km","time":"4h"},
{"day":3,"title":"Gulling to Khullara","description":"Gradual climb through rhododendron forest.","distance":"6km","time":"5h"},
{"day":4,"title":"Khullara Summit Attempt","description":"Early morning climb to Pangarchulla peak.","distance":"10km","time":"10h"},
{"day":5,"title":"Khullara to Joshimath","description":"Descend through forest trail.","distance":"8km","time":"6h"},
{"day":6,"title":"Return to Rishikesh","description":"Drive back.","distance":"255km","time":"9h"}
]'::jsonb,
'{"Apr":"Snow summit climbing","May":"Clear Himalayan views","Oct":"Crisp skies"}'::jsonb,
'38 km'
),

(
'Brahmatal Trek',
'Uttarakhand, India',
'6 Days',
'Moderate',
'12,250 ft',
9500,
10,
'https://images.unsplash.com/photo-1518057111178-44a106bad636',
'Famous winter trek with frozen alpine lakes.',
'Adventure Trek',
'[
{"day":1,"title":"Drive to Lohajung","description":"Scenic drive from Rishikesh.","distance":"250km","time":"9h"},
{"day":2,"title":"Lohajung to Bekaltal","description":"Forest climb with first lake view.","distance":"6km","time":"5h"},
{"day":3,"title":"Bekaltal to Brahmatal","description":"High altitude ridge trek.","distance":"7km","time":"6h"},
{"day":4,"title":"Brahmatal Summit Ridge","description":"Panoramic Himalayan peaks.","distance":"6km","time":"5h"},
{"day":5,"title":"Return to Lohajung","description":"Descend through oak forests.","distance":"10km","time":"7h"},
{"day":6,"title":"Drive to Rishikesh","description":"Return journey.","distance":"250km","time":"9h"}
]'::jsonb,
'{"Jan":"Frozen lakes","Feb":"Snow trekking","Dec":"Fresh snowfall"}'::jsonb,
'29 km'
),

(
'Kuari Pass Trek',
'Uttarakhand, India',
'6 Days',
'Moderate',
'12,516 ft',
9800,
10,
'https://images.unsplash.com/photo-1501785888041-af3ef285b470',
'Lord Curzon trail with views of Nanda Devi.',
'Adventure Trek',
'[
{"day":1,"title":"Rishikesh to Joshimath","description":"Mountain drive.","distance":"250km","time":"9h"},
{"day":2,"title":"Joshimath to Gulling","description":"Drive then trek through forest.","distance":"5km","time":"4h"},
{"day":3,"title":"Gulling to Khullara","description":"Rhododendron forests.","distance":"6km","time":"5h"},
{"day":4,"title":"Kuari Pass Summit","description":"Nanda Devi viewpoint.","distance":"8km","time":"7h"},
{"day":5,"title":"Khullara to Auli","description":"Meadow descent.","distance":"6km","time":"5h"},
{"day":6,"title":"Return to Rishikesh","description":"Drive back.","distance":"250km","time":"9h"}
]'::jsonb,
'{"Apr":"Rhododendron bloom","Oct":"Clear views","Dec":"Snow trekking"}'::jsonb,
'31 km'
),

(
'Har Ki Dun Trek',
'Uttarakhand, India',
'7 Days',
'Moderate',
'11,700 ft',
10500,
5,
'https://images.unsplash.com/photo-1544735716-392fe2489ffa',
'Ancient valley trek known as the Valley of Gods.',
'Adventure Trek',
'[
{"day":1,"title":"Drive to Sankri","description":"Drive from Dehradun.","distance":"200km","time":"8h"},
{"day":2,"title":"Sankri to Taluka","description":"Forest trail trek.","distance":"10km","time":"5h"},
{"day":3,"title":"Taluka to Seema","description":"Walk beside Supin river.","distance":"12km","time":"6h"},
{"day":4,"title":"Seema to Har Ki Dun","description":"Valley trek.","distance":"11km","time":"6h"},
{"day":5,"title":"Explore Valley","description":"Jaundhar glacier views.","distance":"5km","time":"3h"},
{"day":6,"title":"Return to Taluka","description":"Descending trek.","distance":"12km","time":"6h"},
{"day":7,"title":"Drive to Dehradun","description":"Return journey.","distance":"200km","time":"8h"}
]'::jsonb,
'{"Apr":"Spring bloom","Oct":"Golden forests","Dec":"Snow valley"}'::jsonb,
'62 km'
),

(
'Everest Base Camp Trek',
'Nepal',
'14 Days',
'Difficult',
'17,598 ft',
65000,
10,
'https://images.unsplash.com/photo-1544735716-392fe2489ffa',
'Classic trek to the base of Mount Everest.',
'International Trek',
'[
{"day":1,"title":"Kathmandu Arrival","description":"Preparation day.","distance":"0km","time":"0h"},
{"day":2,"title":"Fly to Lukla","description":"Short mountain flight.","distance":"138km","time":"40m"},
{"day":3,"title":"Lukla to Phakding","description":"River valley trek.","distance":"8km","time":"4h"},
{"day":4,"title":"Phakding to Namche","description":"Sherpa capital climb.","distance":"10km","time":"6h"},
{"day":5,"title":"Acclimatization","description":"Everest view hike.","distance":"5km","time":"3h"},
{"day":6,"title":"Namche to Tengboche","description":"Monastery trail.","distance":"9km","time":"5h"},
{"day":7,"title":"Tengboche to Dingboche","description":"High altitude valley.","distance":"10km","time":"6h"},
{"day":8,"title":"Acclimatization Day","description":"Short hike.","distance":"4km","time":"3h"},
{"day":9,"title":"Dingboche to Lobuche","description":"Glacier valley.","distance":"8km","time":"5h"},
{"day":10,"title":"EBC Visit","description":"Reach Everest Base Camp.","distance":"15km","time":"8h"},
{"day":11,"title":"Kala Patthar","description":"Everest sunrise view.","distance":"6km","time":"4h"},
{"day":12,"title":"Return to Namche","description":"Descent.","distance":"18km","time":"7h"},
{"day":13,"title":"Return to Lukla","description":"Final trek.","distance":"15km","time":"7h"},
{"day":14,"title":"Fly to Kathmandu","description":"Trip ends.","distance":"138km","time":"40m"}
]'::jsonb,
'{"Apr":"Climbing season","May":"Clear views","Oct":"Best weather"}'::jsonb,
'128 km'
),

(
'Rupin Pass Trek',
'Uttarakhand / Himachal, India',
'8 Days',
'Difficult',
'15,250 ft',
15500,
8,
'https://images.unsplash.com/photo-1518057111178-44a106bad636',
'Dramatic crossover trek featuring hanging villages, waterfalls, and snow walls.',
'Adventure Trek',
'[
{"day":1,"title":"Drive to Dhaula","description":"Drive from Dehradun to Dhaula village.","distance":"180km","time":"8h"},
{"day":2,"title":"Dhaula to Sewa","description":"Trail along Rupin river valley.","distance":"10km","time":"6h"},
{"day":3,"title":"Sewa to Jakha","description":"Climb through pine forests.","distance":"7km","time":"5h"},
{"day":4,"title":"Jakha to Upper Waterfall Camp","description":"Meadow campsite near waterfall.","distance":"9km","time":"6h"},
{"day":5,"title":"Waterfall to Dhanderas Thatch","description":"Alpine meadow climb.","distance":"7km","time":"5h"},
{"day":6,"title":"Rupin Pass Summit","description":"Snow climb across the pass.","distance":"11km","time":"9h"},
{"day":7,"title":"Descend to Sangla","description":"Descend into Baspa valley.","distance":"10km","time":"6h"},
{"day":8,"title":"Drive to Shimla","description":"Return journey.","distance":"220km","time":"9h"}
]'::jsonb,
'{"May":"Snow bridges","Jun":"Waterfall season","Sep":"Clear Himalayan skies"}'::jsonb,
'54 km'
),

(
'Goechala Trek',
'Sikkim, India',
'11 Days',
'Difficult',
'15,100 ft',
16500,
6,
'https://images.unsplash.com/photo-1518057111178-44a106bad636',
'The best viewpoint trek of Mount Kanchenjunga.',
'Adventure Trek',
'[
{"day":1,"title":"Gangtok Arrival","description":"Drive to Yuksom.","distance":"150km","time":"6h"},
{"day":2,"title":"Yuksom to Sachen","description":"Forest trek.","distance":"8km","time":"5h"},
{"day":3,"title":"Sachen to Tshoka","description":"Climb through rhododendron forest.","distance":"7km","time":"5h"},
{"day":4,"title":"Tshoka to Dzongri","description":"Steep alpine climb.","distance":"10km","time":"6h"},
{"day":5,"title":"Dzongri Acclimatization","description":"Panoramic Himalayan views.","distance":"4km","time":"3h"},
{"day":6,"title":"Dzongri to Thansing","description":"Open valley trek.","distance":"8km","time":"5h"},
{"day":7,"title":"Thansing to Lamuney","description":"Glacial valley hike.","distance":"6km","time":"4h"},
{"day":8,"title":"Goechala Pass","description":"Sunrise Kanchenjunga view.","distance":"12km","time":"9h"},
{"day":9,"title":"Return to Tshoka","description":"Descending trek.","distance":"15km","time":"7h"},
{"day":10,"title":"Return to Yuksom","description":"Forest descent.","distance":"12km","time":"6h"},
{"day":11,"title":"Drive to Gangtok","description":"Return journey.","distance":"150km","time":"6h"}
]'::jsonb,
'{"Apr":"Rhododendron bloom","May":"Best mountain views","Oct":"Autumn clarity"}'::jsonb,
'92 km'
),

(
'Dayara Bugyal Trek',
'Uttarakhand, India',
'5 Days',
'Easy',
'11,830 ft',
8500,
5,
'https://images.unsplash.com/photo-1469334031218-e382a71b716b',
'Massive alpine meadows with panoramic Himalayan views.',
'Adventure Trek',
'[
{"day":1,"title":"Drive to Raithal","description":"Drive from Dehradun.","distance":"185km","time":"8h"},
{"day":2,"title":"Raithal to Gui Camp","description":"Forest trail climb.","distance":"4km","time":"4h"},
{"day":3,"title":"Gui to Dayara Meadows","description":"Open alpine meadows.","distance":"5km","time":"4h"},
{"day":4,"title":"Dayara Summit Ridge","description":"Panoramic Himalayan views.","distance":"6km","time":"5h"},
{"day":5,"title":"Return to Dehradun","description":"Drive back.","distance":"185km","time":"8h"}
]'::jsonb,
'{"Jan":"Snow meadows","Apr":"Green pastures","Oct":"Clear Himalayan views"}'::jsonb,
'15 km'
),

(
'Buran Ghati Trek',
'Himachal Pradesh, India',
'8 Days',
'Difficult',
'15,000 ft',
16500,
10,
'https://images.unsplash.com/photo-1590050860361-ec8f38d38072',
'Thrilling trek famous for its dramatic snow wall descent.',
'Adventure Trek',
'[
{"day":1,"title":"Drive to Janglik","description":"Drive from Shimla.","distance":"150km","time":"7h"},
{"day":2,"title":"Janglik to Dayara Meadows","description":"Forest and meadow trek.","distance":"6km","time":"5h"},
{"day":3,"title":"Dayara to Litham","description":"River valley trail.","distance":"8km","time":"5h"},
{"day":4,"title":"Litham Exploration","description":"Chandranahan lake hike.","distance":"6km","time":"4h"},
{"day":5,"title":"Litham to Pass Camp","description":"Climb toward pass.","distance":"6km","time":"5h"},
{"day":6,"title":"Buran Pass Summit","description":"Snow wall descent.","distance":"10km","time":"8h"},
{"day":7,"title":"River Camp to Barua","description":"Forest descent.","distance":"8km","time":"5h"},
{"day":8,"title":"Drive to Shimla","description":"Return journey.","distance":"150km","time":"7h"}
]'::jsonb,
'{"Jun":"Snow descent","Jul":"Green meadows","Sep":"Clear weather"}'::jsonb,
'54 km'
),

(
'Markha Valley Trek',
'Ladakh, India',
'8 Days',
'Moderate',
'17,060 ft',
16000,
5,
'https://images.unsplash.com/photo-1548013146-72479768bada',
'Classic Ladakh trek through monasteries and desert mountains.',
'Adventure Trek',
'[
{"day":1,"title":"Leh Acclimatization","description":"Rest day.","distance":"0km","time":"0h"},
{"day":2,"title":"Drive to Chilling","description":"Start trek.","distance":"65km","time":"2h"},
{"day":3,"title":"Chilling to Skiu","description":"River crossing trail.","distance":"8km","time":"4h"},
{"day":4,"title":"Skiu to Markha","description":"Village trek.","distance":"10km","time":"6h"},
{"day":5,"title":"Markha to Hankar","description":"Mountain valley trek.","distance":"12km","time":"6h"},
{"day":6,"title":"Hankar to Nimaling","description":"High altitude pasture.","distance":"9km","time":"5h"},
{"day":7,"title":"Kongmaru La Pass","description":"High mountain pass.","distance":"12km","time":"8h"},
{"day":8,"title":"Drive back to Leh","description":"Return journey.","distance":"80km","time":"3h"}
]'::jsonb,
'{"Jun":"Warm trekking season","Jul":"Best weather","Sep":"Clear skies"}'::jsonb,
'75 km'
),

(
'Tarsar Marsar Trek',
'Kashmir, India',
'7 Days',
'Moderate',
'13,200 ft',
14000,
7,
'https://images.unsplash.com/photo-1563725547634-11005c2a110a',
'Beautiful alpine twin lakes trek in Kashmir valley.',
'Adventure Trek',
'[
{"day":1,"title":"Drive to Aru","description":"From Srinagar.","distance":"100km","time":"4h"},
{"day":2,"title":"Aru to Lidderwat","description":"Forest valley trek.","distance":"10km","time":"6h"},
{"day":3,"title":"Lidderwat to Shekwas","description":"Open meadow trek.","distance":"8km","time":"5h"},
{"day":4,"title":"Shekwas to Tarsar Lake","description":"Glacial lake campsite.","distance":"7km","time":"4h"},
{"day":5,"title":"Tarsar to Marsar Lake","description":"High altitude lake trek.","distance":"6km","time":"4h"},
{"day":6,"title":"Return to Lidderwat","description":"Descending trek.","distance":"12km","time":"6h"},
{"day":7,"title":"Return to Srinagar","description":"Drive back.","distance":"100km","time":"4h"}
]'::jsonb,
'{"Jul":"Wildflowers","Aug":"Best lake reflections","Sep":"Golden meadows"}'::jsonb,
'43 km'
),

(
'Bali Pass Trek',
'Uttarakhand, India',
'8 Days',
'Difficult',
'16,207 ft',
17000,
8,
'https://images.unsplash.com/photo-1548013146-72479768bada',
'Remote Himalayan pass connecting Har Ki Dun valley to Yamunotri.',
'Adventure Trek',
'[
{"day":1,"title":"Drive to Sankri","description":"Drive from Dehradun to Sankri village.","distance":"200km","time":"8h"},
{"day":2,"title":"Sankri to Seema","description":"Forest trail along Supin river.","distance":"14km","time":"6h"},
{"day":3,"title":"Seema to Ruinsara Tal","description":"Alpine lake trek.","distance":"10km","time":"6h"},
{"day":4,"title":"Ruinsara Tal Exploration","description":"Acclimatization day.","distance":"4km","time":"3h"},
{"day":5,"title":"Ruinsara to Odari Camp","description":"High altitude meadow trek.","distance":"8km","time":"5h"},
{"day":6,"title":"Bali Pass Summit","description":"Steep glacier crossing.","distance":"12km","time":"10h"},
{"day":7,"title":"Descend to Yamunotri","description":"Temple visit.","distance":"10km","time":"6h"},
{"day":8,"title":"Drive to Dehradun","description":"Return journey.","distance":"210km","time":"9h"}
]'::jsonb,
'{"May":"Snow pass crossing","Jun":"Stable weather","Sep":"Clear mountain views"}'::jsonb,
'58 km'
),

(
'Pin Parvati Pass Trek',
'Himachal Pradesh, India',
'11 Days',
'Very Difficult',
'17,457 ft',
28000,
5,
'https://images.unsplash.com/photo-1518057111178-44a106bad636',
'Legendary trans-Himalayan crossover between lush Parvati valley and barren Spiti desert.',
'Adventure Trek',
'[
{"day":1,"title":"Arrival Kasol","description":"Trip briefing.","distance":"0km","time":"0h"},
{"day":2,"title":"Kasol to Kheerganga","description":"Hot springs campsite.","distance":"12km","time":"6h"},
{"day":3,"title":"Kheerganga to Tunda Bhuj","description":"Forest and valley trek.","distance":"11km","time":"6h"},
{"day":4,"title":"Tunda Bhuj to Thakur Kuan","description":"Glacial valley.","distance":"9km","time":"6h"},
{"day":5,"title":"Thakur Kuan to Odi Thach","description":"Alpine meadow camp.","distance":"7km","time":"5h"},
{"day":6,"title":"Odi Thach to Base Camp","description":"Approach glacier.","distance":"6km","time":"5h"},
{"day":7,"title":"Pin Parvati Pass Summit","description":"Technical glacier climb.","distance":"12km","time":"10h"},
{"day":8,"title":"Manttalai Camp","description":"High altitude plateau.","distance":"8km","time":"6h"},
{"day":9,"title":"Manttalai to Mudh Village","description":"Enter Spiti valley.","distance":"15km","time":"7h"},
{"day":10,"title":"Explore Mudh","description":"Village rest day.","distance":"0km","time":"0h"},
{"day":11,"title":"Drive to Manali","description":"Return via Rohtang.","distance":"190km","time":"8h"}
]'::jsonb,
'{"Jul":"Snow crossings","Aug":"Stable weather","Sep":"Clear skies"}'::jsonb,
'79 km'
),

(
'Stok Kangri Trek',
'Ladakh, India',
'9 Days',
'Very Difficult',
'20,182 ft',
21000,
5,
'https://images.unsplash.com/photo-1590050860361-ec8f38d38072',
'High altitude trekking peak near Leh with panoramic Karakoram views.',
'Adventure Trek',
'[
{"day":1,"title":"Arrival Leh","description":"Acclimatization.","distance":"0km","time":"0h"},
{"day":2,"title":"Leh Exploration","description":"Visit monasteries.","distance":"0km","time":"0h"},
{"day":3,"title":"Drive to Chang Ma","description":"Start trek.","distance":"6km","time":"4h"},
{"day":4,"title":"Chang Ma to Mankorma","description":"Gradual climb.","distance":"5km","time":"4h"},
{"day":5,"title":"Mankorma to Base Camp","description":"Prepare summit.","distance":"4km","time":"3h"},
{"day":6,"title":"Summit Attempt","description":"Night climb to summit.","distance":"12km","time":"12h"},
{"day":7,"title":"Return to Base Camp","description":"Recovery.","distance":"6km","time":"5h"},
{"day":8,"title":"Return to Leh","description":"Drive back.","distance":"15km","time":"6h"},
{"day":9,"title":"Departure","description":"Trip ends.","distance":"0km","time":"0h"}
]'::jsonb,
'{"Jul":"Climbing season","Aug":"Best weather","Sep":"Cold nights"}'::jsonb,
'48 km'
),

(
'Gokyo Lakes Trek',
'Nepal',
'13 Days',
'Difficult',
'17,575 ft',
68000,
8,
'https://images.unsplash.com/photo-1548013146-72479768bada',
'Stunning turquoise glacial lakes in Everest region.',
'International Trek',
'[
{"day":1,"title":"Kathmandu Arrival","description":"Preparation.","distance":"0km","time":"0h"},
{"day":2,"title":"Fly to Lukla","description":"Mountain flight.","distance":"138km","time":"40m"},
{"day":3,"title":"Lukla to Phakding","description":"River valley trek.","distance":"8km","time":"4h"},
{"day":4,"title":"Phakding to Namche Bazaar","description":"Sherpa capital.","distance":"10km","time":"6h"},
{"day":5,"title":"Acclimatization","description":"Everest view hike.","distance":"4km","time":"3h"},
{"day":6,"title":"Namche to Dole","description":"Forest trail.","distance":"11km","time":"6h"},
{"day":7,"title":"Dole to Machhermo","description":"High valley trek.","distance":"8km","time":"5h"},
{"day":8,"title":"Machhermo to Gokyo","description":"Reach lake region.","distance":"7km","time":"5h"},
{"day":9,"title":"Gokyo Ri Summit","description":"Everest panorama.","distance":"4km","time":"3h"},
{"day":10,"title":"Return to Dole","description":"Descend valley.","distance":"11km","time":"6h"},
{"day":11,"title":"Return to Namche","description":"Village trek.","distance":"10km","time":"6h"},
{"day":12,"title":"Return to Lukla","description":"Final trek.","distance":"15km","time":"7h"},
{"day":13,"title":"Fly to Kathmandu","description":"Trip ends.","distance":"138km","time":"40m"}
]'::jsonb,
'{"Apr":"Spring trekking","May":"Clear views","Oct":"Autumn weather"}'::jsonb,
'98 km'
),

(
'Kedarnath Yatra',
'Uttarakhand, India',
'3 Days',
'Moderate',
'11,755 ft',
4500,
0,
'https://images.unsplash.com/photo-1627308595229-7830a5c91f9f',
'Pilgrimage to Kedarnath Temple, one of the twelve Jyotirlingas of Lord Shiva.',
'Yatra',
'[
{"day":1,"title":"Haridwar to Gaurikund","description":"Drive through Rudraprayag and Guptkashi.","distance":"210km","time":"8h"},
{"day":2,"title":"Trek to Kedarnath","description":"Steep trek to Kedarnath temple.","distance":"16km","time":"8h"},
{"day":3,"title":"Return to Haridwar","description":"Descend to Gaurikund and drive back.","distance":"210km","time":"9h"}
]'::jsonb,
'{"May":"Temple opens","Jun":"Peak pilgrimage","Oct":"Closing ceremonies"}'::jsonb,
'32 km'
),

(
'Badrinath Yatra',
'Uttarakhand, India',
'3 Days',
'Easy',
'10,279 ft',
4000,
0,
'https://images.unsplash.com/photo-1597756122949-82e0c7b46a03',
'Sacred Char Dham temple dedicated to Lord Vishnu.',
'Yatra',
'[
{"day":1,"title":"Haridwar to Badrinath","description":"Drive via Joshimath.","distance":"300km","time":"10h"},
{"day":2,"title":"Temple Darshan","description":"Visit Badrinath temple and Mana village.","distance":"2km","time":"2h"},
{"day":3,"title":"Return Journey","description":"Drive back to Haridwar.","distance":"300km","time":"10h"}
]'::jsonb,
'{"May":"Temple opening","Jun":"Pilgrimage peak","Sep":"Peaceful darshan"}'::jsonb,
'0 km'
),

(
'Amarnath Yatra',
'Jammu & Kashmir, India',
'4 Days',
'Difficult',
'12,756 ft',
8000,
0,
'https://images.unsplash.com/photo-1626808642875-0aa545482dfb',
'Sacred cave shrine where the ice Shiva Lingam forms naturally.',
'Religious Trek',
'[
{"day":1,"title":"Srinagar to Pahalgam","description":"Drive to base camp.","distance":"90km","time":"3h"},
{"day":2,"title":"Pahalgam to Sheshnag","description":"Trek through Chandanwari.","distance":"13km","time":"7h"},
{"day":3,"title":"Sheshnag to Amarnath Cave","description":"High altitude trek to cave.","distance":"14km","time":"8h"},
{"day":4,"title":"Return to Srinagar","description":"Descend and drive back.","distance":"90km","time":"5h"}
]'::jsonb,
'{"Jul":"Yatra season","Aug":"Pilgrim peak"}'::jsonb,
'32 km'
),

(
'Vaishno Devi Trek',
'Jammu & Kashmir, India',
'2 Days',
'Easy',
'5,200 ft',
2500,
0,
'https://images.unsplash.com/photo-1578926287944-9e0f3a87a6b2',
'One of the most visited pilgrimage treks dedicated to Goddess Vaishno Devi.',
'Religious Trek',
'[
{"day":1,"title":"Katra to Bhawan","description":"Trek via Ardhkuwari cave.","distance":"14km","time":"6h"},
{"day":2,"title":"Return to Katra","description":"Descend after temple visit.","distance":"14km","time":"5h"}
]'::jsonb,
'{"Mar":"Navratri crowds","Oct":"Autumn pilgrimage"}'::jsonb,
'28 km'
),

(
'Hemkund Sahib Trek',
'Uttarakhand, India',
'4 Days',
'Moderate',
'15,200 ft',
6000,
0,
'https://images.unsplash.com/photo-1519681393784-d120267933ba',
'Sacred Sikh pilgrimage to Hemkund Sahib Gurudwara.',
'Religious Trek',
'[
{"day":1,"title":"Drive to Govindghat","description":"Drive from Rishikesh.","distance":"270km","time":"10h"},
{"day":2,"title":"Trek to Ghangaria","description":"Valley trek along river.","distance":"13km","time":"6h"},
{"day":3,"title":"Hemkund Sahib Visit","description":"Steep climb to Gurudwara.","distance":"6km","time":"4h"},
{"day":4,"title":"Return to Rishikesh","description":"Descend and drive back.","distance":"270km","time":"10h"}
]'::jsonb,
'{"Jun":"Snow melt season","Jul":"Best weather","Sep":"Clear lakes"}'::jsonb,
'38 km'
),

(
'Tirupati Balaji Footpath Trek',
'Andhra Pradesh, India',
'1 Day',
'Easy',
'3,200 ft',
1500,
0,
'https://images.unsplash.com/photo-1581090700227-4c4f50bde90c',
'Ancient footpath pilgrimage route to Tirumala temple.',
'Religious Trek',
'[
{"day":1,"title":"Alipiri to Tirumala","description":"Stone stair pilgrimage route.","distance":"9km","time":"4h"}
]'::jsonb,
'{"Jan":"Winter pilgrimage","Sep":"Festival season"}'::jsonb,
'9 km'
),

(
'Gangotri Gaumukh Yatra',
'Uttarakhand, India',
'6 Days',
'Moderate',
'13,200 ft',
9000,
0,
'https://images.unsplash.com/photo-1501785888041-af3ef285b470',
'Pilgrimage to the origin of the Ganges glacier.',
'Yatra',
'[
{"day":1,"title":"Drive to Gangotri","description":"Drive from Dehradun.","distance":"240km","time":"9h"},
{"day":2,"title":"Gangotri to Chirbasa","description":"Forest trail trek.","distance":"9km","time":"5h"},
{"day":3,"title":"Chirbasa to Bhojbasa","description":"Glacial valley.","distance":"5km","time":"3h"},
{"day":4,"title":"Gaumukh Glacier","description":"Visit source of Ganga.","distance":"6km","time":"4h"},
{"day":5,"title":"Return to Gangotri","description":"Descending trek.","distance":"14km","time":"7h"},
{"day":6,"title":"Return to Dehradun","description":"Drive back.","distance":"240km","time":"9h"}
]'::jsonb,
'{"May":"Temple opening","Jun":"Pilgrim season","Sep":"Clear weather"}'::jsonb
),

(
'Sabarimala Pilgrimage Trek',
'Kerala, India',
'2 Days',
'Moderate',
'4,133 ft',
2000,
0,
'https://images.unsplash.com/photo-1501785888041-af3ef285b470',
'Sacred forest pilgrimage dedicated to Lord Ayyappa.',
'Religious Trek',
'[
{"day":1,"title":"Pamba to Sabarimala","description":"Forest trail pilgrimage.","distance":"5km","time":"3h"},
{"day":2,"title":"Temple Darshan","description":"Return journey.","distance":"5km","time":"3h"}
]'::jsonb,
'{"Nov":"Mandala season","Dec":"Peak pilgrimage"}'::jsonb
);


-- SEED REVIEWS
-- REVIEW 1
INSERT INTO public.reviews (trek_id,user_name,rating,comment,liked,disliked,difficulty_rating,image_url)
SELECT id,'Rahul Mehta',5,
'Absolutely magical trek. The summit sunrise felt unreal and the snow trails were perfect.',
'Summit sunrise view.',
'Cold nights in the tent.',
'Moderate',
'https://i.pravatar.cc/150?img=11'
FROM public.treks LIMIT 1 OFFSET 0;

-- REVIEW 2
INSERT INTO public.reviews (trek_id,user_name,rating,comment,liked,disliked,difficulty_rating,image_url)
SELECT id,'Anika Sharma',5,
'Kashmir truly deserves the name paradise. Every lake looked like a painting.',
'Morning reflection at Vishansar lake.',
'Long trekking days.',
'Difficult',
'https://i.pravatar.cc/150?img=33'
FROM public.treks LIMIT 1 OFFSET 1;

-- REVIEW 3
INSERT INTO public.reviews (trek_id,user_name,rating,comment,liked,disliked,difficulty_rating,image_url)
SELECT id,'Arjun Kapoor',4,
'Hampta Pass gives both lush valleys and desert landscapes in one trek.',
'Crossover into Spiti valley.',
'Wind at the pass was brutal.',
'Moderate',
'https://i.pravatar.cc/150?img=45'
FROM public.treks LIMIT 1 OFFSET 2;

-- REVIEW 4
INSERT INTO public.reviews (trek_id,user_name,rating,comment,liked,disliked,difficulty_rating,image_url)
SELECT id,'Simran Kaur',5,
'Hemkund Sahib trek was spiritual and beautiful at the same time.',
'The lake beside the gurudwara.',
'Steep climb on the last section.',
'Moderate',
'https://i.pravatar.cc/150?img=49'
FROM public.treks LIMIT 1 OFFSET 3;

-- REVIEW 5
INSERT INTO public.reviews (trek_id,user_name,rating,comment,liked,disliked,difficulty_rating,image_url)
SELECT id,'Dev Malhotra',5,
'Pangarchulla summit push was intense but the 360° view of Nanda Devi range was insane.',
'Summit ridge views.',
'Very early summit start.',
'Difficult',
'https://i.pravatar.cc/150?img=52'
FROM public.treks LIMIT 1 OFFSET 4;

-- REVIEW 6
INSERT INTO public.reviews (trek_id,user_name,rating,comment,liked,disliked,difficulty_rating,image_url)
SELECT id,'Priya Iyer',4,
'Valley of Flowers felt like walking inside a painting. Thousands of flowers everywhere.',
'Colorful meadows.',
'Crowds during peak season.',
'Moderate',
'https://i.pravatar.cc/150?img=28'
FROM public.treks LIMIT 1 OFFSET 5;

-- REVIEW 7
INSERT INTO public.reviews (trek_id,user_name,rating,comment,liked,disliked,difficulty_rating,image_url)
SELECT id,'Rohit Verma',5,
'Chadar trek is the craziest winter experience I have ever done.',
'Walking on frozen river.',
'Extreme cold at night.',
'Difficult',
'https://i.pravatar.cc/150?img=19'
FROM public.treks LIMIT 1 OFFSET 6;

-- REVIEW 8
INSERT INTO public.reviews (trek_id,user_name,rating,comment,liked,disliked,difficulty_rating,image_url)
SELECT id,'Karan Patel',4,
'Triund is perfect for beginners. Amazing sunset view over Kangra valley.',
'Sunset camping view.',
'Too crowded on weekends.',
'Easy',
'https://i.pravatar.cc/150?img=63'
FROM public.treks LIMIT 1 OFFSET 7;

-- REVIEW 9
INSERT INTO public.reviews (trek_id,user_name,rating,comment,liked,disliked,difficulty_rating,image_url)
SELECT id,'Sneha Gupta',5,
'Everest Base Camp trek changed my life. Sherpa villages and glaciers everywhere.',
'Namche Bazaar town.',
'Altitude sickness risk.',
'Difficult',
'https://i.pravatar.cc/150?img=15'
FROM public.treks LIMIT 1 OFFSET 8;

-- REVIEW 10
INSERT INTO public.reviews (trek_id,user_name,rating,comment,liked,disliked,difficulty_rating,image_url)
SELECT id,'Amit Thakur',5,
'Har Ki Dun valley is unbelievably peaceful. Ancient villages and alpine forests.',
'Traditional wooden houses.',
'Limited phone signal.',
'Moderate',
'https://i.pravatar.cc/150?img=21'
FROM public.treks LIMIT 1 OFFSET 9;

-- REVIEW 11
INSERT INTO public.reviews (trek_id,user_name,rating,comment,liked,disliked,difficulty_rating,image_url)
SELECT id,'Megha Joshi',4,
'Kuari Pass gives stunning views of Nanda Devi and Dronagiri.',
'Himalayan peak views.',
'Cold nights.',
'Moderate',
'https://i.pravatar.cc/150?img=22'
FROM public.treks LIMIT 1 OFFSET 10;

-- REVIEW 12
INSERT INTO public.reviews (trek_id,user_name,rating,comment,liked,disliked,difficulty_rating,image_url)
SELECT id,'Varun Desai',5,
'Sandakphu trek shows Everest, Makalu, Lhotse and Kanchenjunga together.',
'Sleeping Buddha mountain view.',
'Jeep road sections.',
'Moderate',
'https://i.pravatar.cc/150?img=29'
FROM public.treks LIMIT 1 OFFSET 11;

-- REVIEW 13
INSERT INTO public.reviews (trek_id,user_name,rating,comment,liked,disliked,difficulty_rating,image_url)
SELECT id,'Pooja Nair',4,
'Brahmatal winter trek had frozen lakes and snow forests.',
'Frozen Brahmatal lake.',
'Slippery trails.',
'Moderate',
'https://i.pravatar.cc/150?img=31'
FROM public.treks LIMIT 1 OFFSET 12;

-- REVIEW 14
INSERT INTO public.reviews (trek_id,user_name,rating,comment,liked,disliked,difficulty_rating,image_url)
SELECT id,'Rishi Sharma',5,
'Markha valley trek felt like trekking on another planet.',
'Ladakh desert mountains.',
'Strong sun during the day.',
'Moderate',
'https://i.pravatar.cc/150?img=39'
FROM public.treks LIMIT 1 OFFSET 13;

-- REVIEW 15
INSERT INTO public.reviews (trek_id,user_name,rating,comment,liked,disliked,difficulty_rating,image_url)
SELECT id,'Kabir Singh',4,
'Nag Tibba is the perfect weekend trek near Delhi.',
'Snow summit in winter.',
'Crowded campsites.',
'Easy',
'https://i.pravatar.cc/150?img=40'
FROM public.treks LIMIT 1 OFFSET 14;