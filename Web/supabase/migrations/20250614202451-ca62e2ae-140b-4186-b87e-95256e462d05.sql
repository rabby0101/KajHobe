-- Add a single budget field to jobs table and remove budget_min/budget_max
ALTER TABLE public.jobs 
ADD COLUMN budget integer;

-- Update existing jobs to use the minimum budget as the single budget
UPDATE public.jobs 
SET budget = budget_min 
WHERE budget IS NULL;

-- Make budget not null after setting values
ALTER TABLE public.jobs 
ALTER COLUMN budget SET NOT NULL;

-- Drop the old budget columns
ALTER TABLE public.jobs 
DROP COLUMN budget_min,
DROP COLUMN budget_max;