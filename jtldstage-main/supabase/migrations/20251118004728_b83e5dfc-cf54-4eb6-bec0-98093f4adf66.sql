-- Create project_standards table for linking standards to projects at project level
CREATE TABLE IF NOT EXISTS public.project_standards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  standard_id UUID NOT NULL REFERENCES public.standards(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(project_id, standard_id)
);

-- Enable RLS
ALTER TABLE public.project_standards ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Public can view project standards"
ON public.project_standards
FOR SELECT
USING (true);

CREATE POLICY "Public can manage project standards"
ON public.project_standards
FOR ALL
USING (true);

-- Create index for faster lookups
CREATE INDEX idx_project_standards_project_id ON public.project_standards(project_id);
CREATE INDEX idx_project_standards_standard_id ON public.project_standards(standard_id);