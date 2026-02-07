import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface ReportIssueRequest {
  deploymentId: string;
  shareToken?: string;
  logType: string;
  message: string;
  stackTrace?: string;
  filePath?: string;
  lineNumber?: number;
  metadata?: Record<string, unknown>;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
    const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

    const body: ReportIssueRequest = await req.json();
    const { deploymentId, shareToken, logType, message, stackTrace, filePath, lineNumber, metadata } = body;

    console.log(`[report-local-issue] Received log for deployment ${deploymentId}: ${logType}`);

    if (!deploymentId || !message) {
      throw new Error('deploymentId and message are required');
    }

    // Insert testing log using RPC
    const { data, error } = await supabase.rpc('insert_testing_log_with_token', {
      p_deployment_id: deploymentId,
      p_token: shareToken || null,
      p_log_type: logType || 'info',
      p_message: message.slice(0, 10000), // Limit message size
      p_stack_trace: stackTrace?.slice(0, 50000) || null,
      p_file_path: filePath || null,
      p_line_number: lineNumber || null,
      p_metadata: metadata || {},
    });

    if (error) {
      console.error('[report-local-issue] Error inserting log:', error);
      throw error;
    }

    console.log(`[report-local-issue] Log inserted successfully: ${data?.id}`);

    return new Response(JSON.stringify({ success: true, logId: data?.id }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error: any) {
    console.error('[report-local-issue] Error:', error);
    return new Response(JSON.stringify({ success: false, error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
