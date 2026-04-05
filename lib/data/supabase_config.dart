const String supabaseUrl = 'https://foyqblymliwaylpoftdw.supabase.co';
const String supabaseAnonKey = 'sb_publishable_DtgwWKKY0e61Oc7zfTvbQw_pP9mx93k';

const String supabaseStorageBucket = 'uploads';
const String supabaseTableName = 'paper_uploads';

// Must match mobile deep-link intent filters and Supabase redirect allow list.
const String supabaseEmailRedirectTo = 'passit://auth-callback';

/// Emails that have admin access to manage all papers.
/// Add your admin emails here.
const List<String> adminEmails = [
  'admin@passit.com',
  'ankiambomrichcal.chia@ictuniversity.edu.cm',
  // Add more admin emails as needed
];

