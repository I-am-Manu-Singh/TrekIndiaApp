-- MODERN TRIP INDIA INVENTORY SEED
-- Universal script to handle mixed trip types (Treks, Vacations, Expeditions)

DO $$
DECLARE
    rec RECORD;
BEGIN
    -- 1. Ensure Columns Exist and are JSONB (Most compatible with the app)
    -- inclusions
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='treks' AND column_name='inclusions') THEN
        ALTER TABLE public.treks ADD COLUMN inclusions JSONB DEFAULT '[]'::jsonb;
    ELSE
        ALTER TABLE public.treks ALTER COLUMN inclusions TYPE JSONB USING to_jsonb(inclusions);
    END IF;

    -- carry_list
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='treks' AND column_name='carry_list') THEN
        ALTER TABLE public.treks ADD COLUMN carry_list JSONB DEFAULT '[]'::jsonb;
    ELSE
        ALTER TABLE public.treks ALTER COLUMN carry_list TYPE JSONB USING to_jsonb(carry_list);
    END IF;

    -- latitude/longitude
    ALTER TABLE public.treks ADD COLUMN IF NOT EXISTS latitude NUMERIC DEFAULT 30.7333;
    ALTER TABLE public.treks ADD COLUMN IF NOT EXISTS longitude NUMERIC DEFAULT 76.7794;

    -- exclusions
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='treks' AND column_name='exclusions') THEN
        ALTER TABLE public.treks ADD COLUMN exclusions JSONB DEFAULT '[]'::jsonb;
    END IF;

    -- images (multiple photos gallery)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='treks' AND column_name='images') THEN
        ALTER TABLE public.treks ADD COLUMN images JSONB DEFAULT '[]'::jsonb;
    END IF;

    -- peak_elevation, trail_type, orientation
    ALTER TABLE public.treks ADD COLUMN IF NOT EXISTS peak_elevation TEXT DEFAULT 'N/A';
    ALTER TABLE public.treks ADD COLUMN IF NOT EXISTS trail_type TEXT DEFAULT 'Mixed';
    ALTER TABLE public.treks ADD COLUMN IF NOT EXISTS orientation TEXT DEFAULT 'North';

    -- 1.5. Ensure trip_categories table exists
    CREATE TABLE IF NOT EXISTS public.trip_categories (
        id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        badge_label TEXT,
        icon_name TEXT,
        color_hex TEXT,
        is_special BOOLEAN DEFAULT false,
        display_order INTEGER DEFAULT 0,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );

    -- Seed Categories
    INSERT INTO public.trip_categories (name, badge_label, icon_name, color_hex, is_special, display_order)
    VALUES 
    ('Adventure Trek', 'TREK', 'terrain', '#D32F2F', false, 1),
    ('Religious Trek', 'YATRA', 'temple_hindu', '#FF9800', false, 2),
    ('Vacation', 'HOTEL', 'beach_access', '#00BCD4', true, 3),
    ('Bike Trip', 'RIDE', 'motorcycle', '#4CAF50', true, 4),
    ('Car Trip', 'DRIVE', 'directions_car', '#2196F3', true, 5)
    ON CONFLICT (name) DO NOTHING;

    -- 2. Define Data as a Temporary Table
    CREATE TEMP TABLE temp_treks (
        title TEXT, location TEXT, duration TEXT, difficulty TEXT, altitude TEXT, 
        base_price NUMERIC, discount_percent NUMERIC, rating NUMERIC, 
        image_url TEXT, description TEXT, category TEXT, 
        inclusions JSONB, carry_list JSONB, latitude NUMERIC, longitude NUMERIC,
        exclusions JSONB, images JSONB, peak_elevation TEXT, trail_type TEXT, orientation TEXT
    );

    INSERT INTO temp_treks VALUES 
    ('Goa Beach Escape', 'Goa, India', '4 Days', 'Easy', 'Sea Level', 15000, 10, 4.8, 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?q=80&w=800', 'Relax on the sun-kissed beaches of North and South Goa. Includes water sports and luxury stay.', 'Vacation', '["Hotel Stay", "Water Sports", "Daily Breakfast"]'::jsonb, '["Sunscreen", "Beachwear"]'::jsonb, 15.2993, 74.1240, '["Personal Expenses", "Insurance"]'::jsonb, '["https://images.unsplash.com/photo-1512343879784-a960bf40e7f2"]'::jsonb, 'Sea Level', 'Coastal', 'West'),
    ('Bali Tropical Retreat', 'Bali, Indonesia', '6 Days', 'Easy', 'Sea Level', 45000, 5, 4.9, 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?q=80&w=800', 'Explore the temples, beaches, and rice terraces of Bali.', 'Vacation', '["Resort Stay", "Temple Tours", "Private Car"]'::jsonb, '["Passport", "Swimwear"]'::jsonb, -8.4095, 115.1889, '["Visa Fees", "Personal Shopping"]'::jsonb, '["https://images.unsplash.com/photo-1537996194471-e657df975ab4"]'::jsonb, 'Sea Level', 'Tropical', 'East'),
    ('Leh Ladakh Bike Expedition', 'Leh, Ladakh', '10 Days', 'Hard', '18,000 ft', 35000, 15, 4.9, 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?q=80&w=800', 'The ultimate bike trip through the highest motorable passes in the world.', 'Bike Trip', '["Royal Enfield 500cc", "Backup Vehicle", "Mechanic Support"]'::jsonb, '["Helmet", "Riding Jacket"]'::jsonb, 34.1526, 77.5771, '["Fuel for bike", "Damage recovery"]'::jsonb, '["https://images.unsplash.com/photo-1558981403-c5f9899a28bc"]'::jsonb, '18,379 ft', 'Mountainous', 'North'),
    ('Spiti Valley Car Caravan', 'Spiti Valley', '8 Days', 'Moderate', '14,000 ft', 28000, 10, 4.7, 'https://images.unsplash.com/photo-1585822363148-522f8a44ec43?q=80&w=800', 'A self-drive or chauffeur-driven car trip to the middle land of Spiti.', 'Car Trip', '["SUV Rental", "Oxygen Cylinder", "Guide"]'::jsonb, '["Warm Clothes", "ID Proof"]'::jsonb, 32.2426, 78.0349, '["Personal Snacks", "Phone recharges"]'::jsonb, '["https://images.unsplash.com/photo-1585822363148-522f8a44ec43"]'::jsonb, '14,500 ft', 'Rugged', 'East'),
    ('Kerala Backwater Drive', 'Kerala, India', '5 Days', 'Easy', 'Sea Level', 22000, 10, 4.8, 'https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?q=80&w=800', 'Experience the lush greenery and backwaters of Kerala in a comfortable SUV.', 'Car Trip', '["SUV with Chauffeur", "Houseboat Stay", "Sightseeing"]'::jsonb, '["Cotton Clothes", "Umbrella"]'::jsonb, 10.8505, 76.2711, '["Ayurvedic treatments", "Dinner on land"]'::jsonb, '["https://images.unsplash.com/photo-1602216056096-3b40cc0c9944"]'::jsonb, 'Sea Level', 'Lush/Coastal', 'South'),
    ('Royal Rajasthan Bike Trail', 'Rajasthan, India', '7 Days', 'Moderate', 'N/A', 25000, 10, 4.6, 'https://images.unsplash.com/photo-1593627010886-d34828365da7?q=80&w=800', 'Ride through the golden deserts and historic forts of Rajasthan.', 'Bike Trip', '["Royal Enfield Classic", "Fort Stays", "Mechanic"]'::jsonb, '["Sunscreen", "Riding Boots"]'::jsonb, 27.0238, 74.2179, '["Personal Fort Entries", "Camel Safari lunch"]'::jsonb, '["https://images.unsplash.com/photo-1593627010886-d34828365da7"]'::jsonb, 'N/A', 'Desert', 'North-West'),
    ('Dubai City of Gold', 'Dubai, UAE', '5 Days', 'Easy', 'N/A', 55000, 5, 4.7, 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?q=80&w=800', 'A luxurious vacation in the heart of the Middle East.', 'Vacation', '["Flights", "Luxury Hotel", "Desert Safari"]'::jsonb, '["Passport", "Fancy Wear"]'::jsonb, 25.2048, 55.2708, '["Visa Fees", "Burj Khalifa Top Entry"]'::jsonb, '["https://images.unsplash.com/photo-1512453979798-5ea266f8880c"]'::jsonb, 'Sea Level', 'Urban', 'West'),
    ('Andaman Island Bliss', 'Andaman & Nicobar', '6 Days', 'Easy', 'Sea Level', 38000, 12, 4.9, 'https://images.unsplash.com/photo-1589135393572-393ff8981433?q=80&w=800', 'Pristine white beaches and crystal clear blue waters.', 'Vacation', '["Island Hopping", "Scuba Diving", "Beach Resort"]'::jsonb, '["Swimwear", "Dry Bag"]'::jsonb, 11.7401, 92.6586, '["Personal Scuba photos", "Evening Snacks"]'::jsonb, '["https://images.unsplash.com/photo-1589135393572-393ff8981433"]'::jsonb, 'Sea Level', 'Marine', 'East');

    -- 3. Insert only if they don't exist
    FOR rec IN SELECT * FROM temp_treks LOOP
        IF NOT EXISTS (SELECT 1 FROM public.treks WHERE title = rec.title) THEN
            INSERT INTO public.treks (
                title, location, duration, difficulty, altitude, 
                base_price, discount_percent, rating, 
                image_url, description, category, 
                inclusions, carry_list, latitude, longitude,
                exclusions, images, peak_elevation, trail_type, orientation
            ) VALUES (
                rec.title, rec.location, rec.duration, rec.difficulty, rec.altitude, 
                rec.base_price, rec.discount_percent, rec.rating, 
                rec.image_url, rec.description, rec.category, 
                rec.inclusions, rec.carry_list, rec.latitude, rec.longitude,
                rec.exclusions, rec.images, rec.peak_elevation, rec.trail_type, rec.orientation
            );
        END IF;
    END LOOP;

    DROP TABLE temp_treks;
END $$;
