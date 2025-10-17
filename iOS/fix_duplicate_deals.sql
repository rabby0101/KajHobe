-- Fix duplicate deal creation by removing the problematic trigger
-- The Swift code already handles deal creation properly with duplicate prevention

-- Drop the trigger that's causing duplicate deals
DROP TRIGGER IF EXISTS on_offer_acceptance ON notifications;

-- Drop the function as well since it's no longer needed
DROP FUNCTION IF EXISTS handle_offer_acceptance();

-- The handle_interest_acceptance trigger can stay as it properly handles conversation creation
-- and doesn't conflict with Swift code

-- Note: Real-time functionality is handled by Supabase's built-in real-time subscriptions,
-- not by these custom triggers, so removing this won't affect real-time notifications.