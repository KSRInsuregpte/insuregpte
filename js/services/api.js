(function initializeDashboardApi(global) {
    'use strict';

    function getClient() {
        const supabaseModule = global.InsureGPTESupabase;
        if (!supabaseModule || typeof supabaseModule.getClient !== 'function') {
            throw new Error('Centralized Supabase client is not initialized.');
        }
        return supabaseModule.getClient();
    }

    async function getSubjectCatalogue() {
        const client = getClient();
        const { data, error } = await client.rpc('get_subject_catalogue');
        if (error) {
            throw error;
        }
        return data;
    }

    async function getMyQuizAttempts() {
        const client = getClient();
        const { data, error } = await client.rpc('get_my_quiz_attempts');
        if (error) {
            throw error;
        }
        return data;
    }

    async function checkIfAdmin() {
        const client = getClient();
        const { data, error } = await client.rpc('fn_is_admin');
        if (error) {
            throw error;
        }
        return data;
    }

    async function getMyProfile() {
        const client = getClient();
        const { data, error } = await client.rpc('get_my_profile');
        if (error) {
            throw error;
        }
        return data;
    }

    global.InsureGPTEApi = {
        getSubjectCatalogue,
        getMyQuizAttempts,
        checkIfAdmin,
        getMyProfile
    };
}(window));
