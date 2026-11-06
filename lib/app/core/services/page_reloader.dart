/// Test seam for reloading the web page, so a newer build is fetched.
/// Native builds have nothing to reload, so their adapter does nothing.
abstract class IPageReloader {
  void reload();
}
