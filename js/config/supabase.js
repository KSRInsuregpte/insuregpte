(function initializeSharedSupabaseClient(global) {
    'use strict';

    const SUPABASE_URL = 'https://tvjsivuibvzybdbjtesq.supabase.co';
    const SUPABASE_ANON_KEY =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        + 'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2anNpdnVpYnZ6eWJkYmp0ZXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0MTI1MjksImV4cCI6MjA5ODk4ODUyOX0.'
        + 'meGmoVDJE25neU_na5xl8u3CYxA24M7tqcG5ez-emaU';

    let cachedClient = null;

    function getClient() {
        if (cachedClient) {
            return cachedClient;
        }

        if (!global.supabase || typeof global.supabase.createClient !== 'function') {
            throw new Error('Supabase SDK is not loaded.');
        }

        const sessionControl = global.InsureGPTESessionControl;
        const options = sessionControl && typeof sessionControl.clientOptions === 'function'
            ? sessionControl.clientOptions()
            : undefined;

        cachedClient = global.supabase.createClient(
            SUPABASE_URL,
            SUPABASE_ANON_KEY,
            options
        );

        return cachedClient;
    }

    global.InsureGPTESupabase = {
        getClient
    };
}(window));
