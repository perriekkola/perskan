-- Private namespace for the vendored Simple Item Level (Kemayo, BSD).
--
-- Files loaded from another addon's toc receive that addon's name and private table
-- from `...`, which would have the vendored files write their state into Perskan's
-- table and, worse, hang their saved variables off PerskanDB. They take this table
-- instead - the `[Perskan]`-marked first line of each vendored file is the only change
-- needed to redirect them.

PerskanSimpleItemLevel = {
    -- The addon whose ADDON_LOADED means "our saved variables are ready".
    HOST_ADDON = ...,
}
