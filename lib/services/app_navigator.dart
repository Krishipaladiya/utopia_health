import 'package:flutter/material.dart';

/// Lets services (login expiry, push taps) navigate without a BuildContext.
final appNavigatorKey = GlobalKey<NavigatorState>();
