enum AppMode { desktop, controller }

extension AppModeLabel on AppMode {
  String get title => switch (this) {
    AppMode.desktop => 'Desktop Game',
    AppMode.controller => 'Motion Controller',
  };

  String get subtitle => switch (this) {
    AppMode.desktop => 'Create a room and run the main game screen.',
    AppMode.controller => 'Connect your phone and send motion events.',
  };
}
