-- FINAL RECTIFIED SEED DATA FOR VACATION PACKAGES AND PREMIUM TRIPS
-- This script fixes column name mismatches and UUID type issues.

-- 1. Ensure the treks table has all necessary columns as JSONB
-- We first check if they exist, and if so, we ensure they are JSONB
DO $$ 
BEGIN 
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
END $$;

-- 2. Ensure trek_packages table exists
CREATE TABLE IF NOT EXISTS public.trek_packages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trek_id UUID REFERENCES public.treks(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    price NUMERIC NOT NULL,
    description TEXT,
    inclusions JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
-- Ensure trek_packages.inclusions is also JSONB if it already existed as text[]
ALTER TABLE public.trek_packages ALTER COLUMN inclusions TYPE JSONB USING to_jsonb(inclusions);

-- 3. Update existing Goa/Beach entries to the 'Vacation' category
UPDATE public.treks 
SET category = 'Vacation' 
WHERE title ILIKE '%goa%' OR title ILIKE '%beach%';

-- 4. Seed new high-fidelity vacation data
-- Using subqueries to handle UUIDs safely without hardcoding them

DO $$
DECLARE
    goa_id UUID;
    manali_id UUID;
    leh_id UUID;
    andaman_id UUID;
BEGIN
    -- Luxury Goa Beach Retreat
    IF NOT EXISTS (SELECT 1 FROM public.treks WHERE title = 'Luxury Goa Beach Retreat') THEN
        INSERT INTO public.treks (title, location, description, base_price, discount_percent, rating, duration, category, difficulty, altitude, image_url, inclusions, carry_list, latitude, longitude, itinerary, best_months, seasonal_info, pickup_options, total_distance, exclusions, images, peak_elevation, trail_type, orientation)
        VALUES (
            'Luxury Goa Beach Retreat', 
            'Goa, India', 
            'Experience the serene beaches of South Goa with premium resort stay and private yacht tour.', 
            25000, 10, 4.9, '4 Days, 3 Nights', 'Vacation', 'Leisure', 'Sea Level', 
            'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?q=80&w=1000', 
            '["Luxury Resort", "Private Yacht", "Airport Transfer"]'::jsonb, 
            '["Sunscreen", "Beachwear", "Sunglasses"]'::jsonb, 
            15.2993, 74.1240,
            '[{"day": 1, "title": "Arrival & Sunset Yacht", "description": "Private transfer to resort followed by a sunset cruise."}, {"day": 2, "title": "South Goa Beaches", "description": "Leisurely day at Palolem and Agonda beaches."}, {"day": 3, "title": "Heritage & Spice Plantation", "description": "Visit Old Goa churches and a lush spice farm."}, {"day": 4, "title": "Departure", "description": "Leisure breakfast and transfer to airport."}]'::jsonb,
            'Nov-Feb',
            '{"Dec": "Peak Season", "Jun": "Monsoon Bloom"}'::jsonb,
            '[{"location": "Dabolim Airport", "price": 0}, {"location": "Madgaon Station", "price": 500}]'::jsonb,
            'N/A',
            '["Personal Expenses", "Insurance", "Alcoholic Beverages"]'::jsonb,
            '["https://images.unsplash.com/photo-1512343879784-a960bf40e7f2", "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1"]'::jsonb,
            'Sea Level',
            'Coastal',
            'West'
        )
        RETURNING id INTO goa_id;
        
        INSERT INTO public.trek_packages (trek_id, name, price, description, inclusions)
        VALUES (goa_id, 'Beachfront Villa', 35000, 'Stay in a private villa with pool', '["All Meals", "Private Butler", "Private Pool"]'::jsonb);
    END IF;

    -- Manali Adventure Package
    IF NOT EXISTS (SELECT 1 FROM public.treks WHERE title = 'Manali Adventure Package') THEN
        INSERT INTO public.treks (title, location, description, base_price, discount_percent, rating, duration, category, difficulty, altitude, image_url, inclusions, carry_list, latitude, longitude, itinerary, best_months, seasonal_info, pickup_options, total_distance, exclusions, images, peak_elevation, trail_type, orientation)
        VALUES (
            'Manali Adventure Package', 
            'Manali, Himachal', 
            'All-inclusive package featuring paragliding, river rafting, and 5-star mountain view stay.', 
            32000, 15, 4.8, '5 Days, 4 Nights', 'Package', 'Moderate', '6,726 ft', 
            'https://images.unsplash.com/photo-1626621341517-bbf3d9990a23?q=80&w=1000', 
            '["Paragliding", "River Rafting", "5-Star Stay"]'::jsonb, 
            '["Warm Clothes", "Boots", "Gloves"]'::jsonb, 
            32.2432, 77.1892,
            '[{"day": 1, "title": "Manali Arrival", "description": "Check-in at luxury resort with mountain views."}, {"day": 2, "title": "Solang Valley Adventure", "description": "Paragliding and ATV rides in Solang."}, {"day": 3, "title": "Rohtang Pass Expedition", "description": "Snow activities and panoramic Himalayan views."}, {"day": 4, "title": "Beas River Rafting", "description": "Thrilling 7km rafting session in Beas river."}, {"day": 5, "title": "Departure", "description": "Local market visit and drop-off."}]'::jsonb,
            'Apr-Jun, Sep-Dec',
            '{"Dec": "Snowfall Peak", "May": "Pleasant Meadows"}'::jsonb,
            '[{"location": "Kullu Airport", "price": 1500}, {"location": "Manali Bus Stand", "price": 0}]'::jsonb,
            'N/A',
            '["Lunch during travel", "Personal shopping", "Tips for staff"]'::jsonb,
            '["https://images.unsplash.com/photo-1626621341517-bbf3d9990a23", "https://images.unsplash.com/photo-1501785888041-af3ef285b470"]'::jsonb,
            '8,500 ft (Rohtang Pass)',
            'Mountainous',
            'North'
        )
        RETURNING id INTO manali_id;
    END IF;

    -- Leh Ladakh Bike Expedition
    IF NOT EXISTS (SELECT 1 FROM public.treks WHERE title = 'Leh Ladakh Bike Expedition') THEN
        INSERT INTO public.treks (title, location, description, base_price, discount_percent, rating, duration, category, difficulty, altitude, image_url, inclusions, carry_list, latitude, longitude, itinerary, best_months, seasonal_info, pickup_options, total_distance, exclusions, images, peak_elevation, trail_type, orientation)
        VALUES (
            'Leh Ladakh Bike Expedition', 
            'Leh, Ladakh', 
            'The ultimate road trip across the highest passes. Includes bullet rentals, backup vehicle, and stays.', 
            45000, 12, 4.9, '9 Days, 8 Nights', 'Bike Trip', 'Challenging', '18,000 ft', 
            'https://images.unsplash.com/photo-1581791534721-e599df4417f7?q=80&w=1000', 
            '["Royal Enfield 500cc", "Backup Vehicle", "Oxygen Support"]'::jsonb, 
            '["Helmet", "Riding Gear", "Heavy Woolens"]'::jsonb, 
            34.1526, 77.5771,
            '[{"day": 1, "title": "Leh Arrival", "description": "Mandatory acclimatization day."}, {"day": 2, "title": "Local Leh Loop", "description": "Shanti Stupa and Leh Palace ride."}, {"day": 3, "title": "Khardung La Pass", "description": "Ride to the world''s highest motorable pass."}, {"day": 4, "title": "Nubra Valley", "description": "Camel safari in Hunder dunes."}, {"day": 5, "title": "Pangong Lake", "description": "Ride to the iconic blue lake."}, {"day": 6, "title": "Rezang La War Memorial", "description": "Visit the site of historic bravery."}, {"day": 7, "title": "Chang La Pass", "description": "Crossing the high pass back to Leh."}, {"day": 8, "title": "Magnetic Hill", "description": "Experience gravity-defying phenomenon."}, {"day": 9, "title": "Departure", "description": "Drop off at Leh airport."}]'::jsonb,
            'Jun-Sep',
            '{"Jul": "Stable Weather", "Sep": "Early Snowfall"}'::jsonb,
            '[{"location": "Leh Airport", "price": 0}]'::jsonb,
            '850 km',
            '["Fuel for bikes", "Damage to bike", "Riding boots"]'::jsonb,
            '["https://images.unsplash.com/photo-1581791534721-e599df4417f7", "https://images.unsplash.com/photo-1544735716-392fe2489ffa"]'::jsonb,
            '18,379 ft (Khardung La)',
            'High Altitude Highway',
            'North'
        )
        RETURNING id INTO leh_id;
    END IF;

    -- Andaman Island Escape
    IF NOT EXISTS (SELECT 1 FROM public.treks WHERE title = 'Andaman Island Escape') THEN
        INSERT INTO public.treks (title, location, description, base_price, discount_percent, rating, duration, category, difficulty, altitude, image_url, inclusions, carry_list, latitude, longitude, itinerary, best_months, seasonal_info, pickup_options, total_distance, exclusions, images, peak_elevation, trail_type, orientation)
        VALUES (
            'Andaman Island Escape', 
            'Havelock, Andaman', 
            'Dive into the turquoise waters. Scuba diving, snorkeling, and premium beach-front villas.', 
            55000, 20, 5.0, '6 Days, 5 Nights', 'Vacation', 'Leisure', 'Sea Level', 
            'https://images.unsplash.com/photo-1589135393572-393ff8981433?q=80&w=1000', 
            '["Scuba Diving", "Villa Stay", "Speedboat Transfer"]'::jsonb, 
            '["Swimwear", "Dry Bag", "Flip-flops"]'::jsonb, 
            12.0191, 92.9567,
            '[{"day": 1, "title": "Port Blair Arrival", "description": "Visit Cellular Jail and Light & Sound show."}, {"day": 2, "title": "Speedboat to Havelock", "description": "Check-in at premium beach resort."}, {"day": 3, "title": "Radhanagar Beach", "description": "Sunset at Asia''s best beach."}, {"day": 4, "title": "Scuba & Snorkeling", "description": "Explore Elephant beach coral reefs."}, {"day": 5, "title": "Neil Island", "description": "Visit Natural Bridge and Bharatpur beach."}, {"day": 6, "title": "Departure", "description": "Return to Port Blair and flight home."}]'::jsonb,
            'Oct-May',
            '{"Jan": "Clear Blue Waters", "Aug": "Heavy Rainfalls"}'::jsonb,
            '[{"location": "Veer Savarkar Airport", "price": 0}]'::jsonb,
            'N/A',
            '["Snacks on ferry", "Underwater photography", "Jet ski rides"]'::jsonb,
            '["https://images.unsplash.com/photo-1589135393572-393ff8981433", "https://images.unsplash.com/photo-1563725547634-11005c2a110a"]'::jsonb,
            'Sea Level',
            'Marine/Island',
            'East'
        )
        RETURNING id INTO andaman_id;
    END IF;

END $$;
