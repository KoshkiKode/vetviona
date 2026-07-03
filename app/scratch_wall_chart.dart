import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../providers/tree_provider.dart';
import '../models/person.dart';
import '../models/partnership.dart';
import 'tree_layout.dart';
import 'fan_chart_screen.dart'; // We can redirect to fan chart if selected

// We will implement WallChartScreen
