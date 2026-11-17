// A minimal stand-in for what Supabase puts around a migration, for PGlite:
// the auth schema, the API roles, and the default grants.
//
// Supabase grants every API role full privileges on new tables and functions in
// public; RLS and explicit revokes are what actually lock them down. The stub
// mirrors that so a missing revoke shows up in the tests.
export const SUPABASE_STUB = `
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin bypassrls;
  create schema auth;
  create table auth.users (id uuid primary key);
  create function auth.uid() returns uuid language sql stable
    as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  grant usage on schema auth to anon, authenticated, service_role;
  grant execute on function auth.uid() to anon, authenticated, service_role;
  grant usage on schema public to anon, authenticated, service_role;
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
`;
