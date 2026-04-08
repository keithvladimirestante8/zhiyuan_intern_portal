import 'dart:async' show Timer, TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dashboard_screen.dart';
import 'main.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen>
    with TickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;

  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _schoolController = TextEditingController();
  final _courseController = TextEditingController();
  final _hoursController = TextEditingController();

  final FocusNode _schoolFocusNode = FocusNode();
  final FocusNode _courseFocusNode = FocusNode();

  Timer? _debounceTimer;

  late AnimationController _bgAnimationController;
  late AnimationController _entryController;

  bool _isLoading = false;
  Uint8List? _selectedPhotoBytes;
  Uint8List? _selectedResumeBytes;
  String? _uploadedPhotoUrl;
  String? _uploadedResumeUrl;
  String _selectedGender = 'Male';

  static const Color zLogoGold = Color(0xFFC2A984);
  static const Color zNavyBlue = Color(0xFF1A237E);
  static const Color zOnyxBlack = Color(0xFF1A1C20);

  // Static aliases for normalization
  final Map<String, String> _schoolAliases = {
    "PTC": "Pateros Technological College",
    "RTU": "Rizal Technological College",
    "STI": "STI College",
    "PUP": "Polytechnic University Of The Philippines",
    "UST": "University Of Santo Tomas",
    "UP": "University Of The Philippines",
    "DLSU": "De La Salle University",
    "TUP": "Technological University Of The Philippines",
    "PLM": "Pamantasan Ng Lungsod Ng Maynila",
  };

  final Map<String, String> _courseAliases = {
    "BSIT": "Bachelor Of Science In Information Technology",
    "BSCS": "Bachelor Of Science In Computer Science",
    "BSCPE": "Bachelor Of Science In Computer Engineering",
    "BSEE": "Bachelor Of Science In Electrical Engineering",
    "BSECE": "Bachelor Of Science In Electronics Engineering",
    "BACOMM": "Bachelor Of Arts in Communication",
    "BSCE": "Bachelor Of Science In Civil Engineering",
    "BSPSYCH": "Bachelor Of Science In Psychology",
    "BSPSY": "Bachelor Of Science In Psychology",
  };

  late List<String> _dynamicSchoolSuggestions = _schoolAliases.values.toList();
  late List<String> _dynamicCourseSuggestions = _courseAliases.values.toList();

  @override
  void initState() {
    super.initState();
    _checkExistingProfile();
    _fetchDynamicSuggestions();

    _usernameController.addListener(_onTextChanged);
    _phoneController.addListener(_onTextChanged);
    _addressController.addListener(_onTextChanged);
    _schoolController.addListener(_onTextChanged);
    _courseController.addListener(_onTextChanged);
    _hoursController.addListener(_onTextChanged);

    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDraft();
    });
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {});
        _saveDraft();
      }
    });
  }

  bool _isFormValid() {
    if (_usernameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _schoolController.text.trim().isEmpty ||
        _courseController.text.trim().isEmpty ||
        _hoursController.text.trim().isEmpty) {
      return false;
    }

    if (!_isValidPhone(_phoneController.text.trim())) {
      return false;
    }

    final parsedHours = double.tryParse(_hoursController.text.trim());
    if (parsedHours == null || parsedHours < 100) {
      return false;
    }

    return true;
  }

  bool _isValidPhone(String phone) {
    final cleanedPhone = phone.replaceAll(RegExp(r'[\s-]'), '');
    final regex = RegExp(r'^(\d{10}|\+63\d{10})$');
    return regex.hasMatch(cleanedPhone);
  }

  Future<void> _saveDraft() async {
    if (user == null || _isLoading) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final draftKey = 'profile_draft_${user!.uid}';

      final draftData = json.encode({
        'username': _usernameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'school': _schoolController.text,
        'course': _courseController.text,
        'hours': _hoursController.text,
        'gender': _selectedGender,
        'savedAt': DateTime.now().toIso8601String(),
      });

      await prefs.setString(draftKey, draftData);
    } catch (e) {
      debugPrint("Auto-save error: $e");
    }
  }

  Future<void> _loadDraft() async {
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final draftData = prefs.getString('profile_draft_${user!.uid}');

      if (draftData != null) {
        final draft = json.decode(draftData) as Map<String, dynamic>;
        final savedAt = DateTime.parse(draft['savedAt']);

        // Only load draft if less than 24 hours old
        if (DateTime.now().difference(savedAt).inHours < 24) {
          setState(() {
            if (_usernameController.text.isEmpty)
              _usernameController.text = draft['username'] ?? "";
            if (_phoneController.text.isEmpty)
              _phoneController.text = draft['phone'] ?? "";
            if (_addressController.text.isEmpty)
              _addressController.text = draft['address'] ?? "";
            if (_schoolController.text.isEmpty)
              _schoolController.text = draft['school'] ?? "";
            if (_courseController.text.isEmpty)
              _courseController.text = draft['course'] ?? "";
            if (_hoursController.text.isEmpty)
              _hoursController.text = draft['hours'] ?? "";
            _selectedGender = draft['gender'] ?? 'Male';
          });

          if (mounted) {
            _showSnackbar(
              "Draft restored from ${savedAt.hour}:${savedAt.minute.toString().padLeft(2, '0')}",
              Colors.blue,
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Load draft error: $e");
    }
  }

  Future<void> _fetchDynamicSuggestions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('intern_profiles')
          .get();
      final Set<String> schools = {};
      final Set<String> courses = {};

      schools.addAll(_schoolAliases.values);
      courses.addAll(_courseAliases.values);

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['school'] != null &&
            data['school'].toString().trim().isNotEmpty) {
          schools.add(data['school'].toString().trim());
        }
        if (data['course'] != null &&
            data['course'].toString().trim().isNotEmpty) {
          courses.add(data['course'].toString().trim());
        }
      }

      if (mounted) {
        setState(() {
          _dynamicSchoolSuggestions = schools.toList();
          _dynamicCourseSuggestions = courses.toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching dynamic suggestions: $e");
    }
  }

  String _normalizeText(String input, Map<String, String> aliases) {
    String trimmed = input.trim();
    if (trimmed.isEmpty) return "";
    String upper = trimmed.toUpperCase();

    if (aliases.containsKey(upper)) return aliases[upper]!;

    List<String> words = trimmed.split(' ');
    if (words.isNotEmpty) {
      String firstWordUpper = words[0].toUpperCase();
      if (aliases.containsKey(firstWordUpper)) {
        words[0] = aliases[firstWordUpper]!;
        return words.map((w) => _formatToTitleCase(w)).join(' ');
      }
    }
    return _formatToTitleCase(trimmed);
  }

  String _formatToTitleCase(String text) {
    if (text.trim().isEmpty) return "";
    const acronyms = [
      'BS',
      'BA',
      'MS',
      'MA',
      'IT',
      'CS',
      'CPE',
      'CE',
      'BSA',
      'PHD',
    ];

    return text
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) {
          String upper = w.toUpperCase();
          if (acronyms.contains(upper)) return upper;
          if (w.length <= 1) return w.toUpperCase();
          return w[0].toUpperCase() + w.substring(1).toLowerCase();
        })
        .join(' ');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _bgAnimationController.dispose();
    _entryController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _schoolController.dispose();
    _courseController.dispose();
    _hoursController.dispose();
    _schoolFocusNode.dispose();
    _courseFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkExistingProfile() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('intern_profiles')
        .doc(user!.uid)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _usernameController.text = data['username'] ?? "";
        _phoneController.text = data['phone'] ?? "";
        _addressController.text = data['address'] ?? "";
        _schoolController.text = data['school'] ?? "";
        _courseController.text = data['course'] ?? "";
        _hoursController.text = (data['required_hours'] ?? 0).toString();
        _selectedGender = data['gender'] ?? 'Male';
        _uploadedPhotoUrl = data['photo_url'];
        _uploadedResumeUrl = data['resume_url'];
      });
    }
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();
    final result = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (result != null) {
      final bytes = await result.readAsBytes();
      setState(() {
        _selectedPhotoBytes = bytes;
      });
      _onTextChanged();
    }
  }

  Future<void> _pickResume() async {
    HapticFeedback.lightImpact();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      final bytes = result.files.first.bytes;
      setState(() {
        _selectedResumeBytes = bytes;
      });
      _onTextChanged();
    }
  }

  void _handlePdfPreview() async {
    if (_selectedResumeBytes != null) {
      // Check file size (5MB limit for mobile)
      const fileSizeLimit = 5 * 1024 * 1024; // 5MB in bytes
      final isLargeFile = _selectedResumeBytes!.length > fileSizeLimit;
      
      if (isLargeFile) {
        _showSnackbar("File too large for preview. Please use a smaller PDF.", Colors.orange);
        return;
      }

      try {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: zNavyBlue,
                    title: const Text("PDF PREVIEW"),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: SfPdfViewer.memory(
                        _selectedResumeBytes!,
                        canShowScrollHead: true,
                        canShowScrollStatus: true,
                        onDocumentLoaded: (details) {
                          debugPrint("PDF loaded successfully");
                        },
                        onDocumentLoadFailed: (details) {
                          debugPrint("PDF load failed: ${details.error}");
                          Navigator.pop(context);
                          _showSnackbar("Failed to load PDF. Try a different file.", Colors.red);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } catch (e) {
        debugPrint("PDF preview error: $e");
        _showSnackbar("Unable to preview this PDF file.", Colors.red);
      }
    } else if (_uploadedResumeUrl != null) {
      try {
        final Uri url = Uri.parse(_uploadedResumeUrl!);
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.externalApplication,
          );
        } else {
          _showSnackbar("Cannot open resume URL", Colors.red);
        }
      } catch (e) {
        debugPrint("URL launch error: $e");
        _showSnackbar("Failed to open resume", Colors.red);
      }
    }
  }

  Future<String?> _uploadToCloudinaryWithRetry({
    required Uint8List fileBytes,
    required String fileName,
    required String publicId,
    int maxRetries = 3,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final url = await _uploadToCloudinary(
          fileBytes: fileBytes,
          fileName: fileName,
          publicId: publicId,
        );
        return url;
      } catch (e) {
        if (attempt == maxRetries - 1) rethrow;
        await Future.delayed(Duration(milliseconds: 1000 * (attempt + 1)));
      }
    }
    return null;
  }

  Future<String> _uploadToCloudinary({
    required Uint8List fileBytes,
    required String fileName,
    required String publicId,
  }) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/dqn0uoaqm/auto/upload',
    );
    final request = http.MultipartRequest('POST', url);
    request.fields['upload_preset'] = 'zhiyuan_preset';
    request.fields['public_id'] = publicId;
    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );

    final response = await request.send();
    final respStr = await response.stream.bytesToString();
    final jsonResponse = json.decode(respStr);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonResponse['secure_url'];
    } else {
      final errorMessage =
          jsonResponse['error']?['message'] ?? 'Unknown Cloudinary Error';
      throw Exception(errorMessage);
    }
  }

  Future<void> _saveProfile() async {
    if (!_isFormValid()) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final parsedHours = double.parse(_hoursController.text.trim());

      if (_selectedPhotoBytes != null) {
        final photoUrl = await _uploadToCloudinaryWithRetry(
          fileBytes: _selectedPhotoBytes!,
          fileName: 'profile_pic',
          publicId: "profile_${user!.uid}",
        );
        if (photoUrl != null) {
          _uploadedPhotoUrl = photoUrl;
        }
      }

      if (_selectedResumeBytes != null) {
        final resumeUrl = await _uploadToCloudinaryWithRetry(
          fileBytes: _selectedResumeBytes!,
          fileName: 'resume.pdf',
          publicId: "resume_${user!.uid}",
        );
        if (resumeUrl != null) {
          _uploadedResumeUrl = resumeUrl;
        }
      }

      await FirebaseFirestore.instance
          .collection('intern_profiles')
          .doc(user?.uid)
          .set({
            'username': _formatToTitleCase(_usernameController.text),
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'gender': _selectedGender,
            'school': _normalizeText(_schoolController.text, _schoolAliases),
            'course': _normalizeText(_courseController.text, _courseAliases),
            'required_hours': parsedHours,
            'photo_url': _uploadedPhotoUrl,
            'resume_url': _uploadedResumeUrl,
            'profile_setup_completed': true,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Clear draft upon successful save
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('profile_draft_${user!.uid}');
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } on SocketException {
      _showSnackbar("No internet connection", Colors.redAccent);
    } on TimeoutException {
      _showSnackbar("Connection timeout. Please try again.", Colors.redAccent);
    } catch (e) {
      debugPrint("UPLOAD ERROR: $e");
      _showSnackbar("Error: ${e.toString()}", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  double _calculateProgress() {
    int filledFields = 0;
    int totalFields = 7;

    if (_usernameController.text.trim().isNotEmpty) filledFields++;
    if (_phoneController.text.trim().isNotEmpty) filledFields++;
    if (_addressController.text.trim().isNotEmpty) filledFields++;
    if (_schoolController.text.trim().isNotEmpty) filledFields++;
    if (_courseController.text.trim().isNotEmpty) filledFields++;

    final parsedHours = double.tryParse(_hoursController.text.trim());
    if (parsedHours != null && parsedHours >= 100) {
      filledFields++;
    }

    if (_selectedPhotoBytes != null || _uploadedPhotoUrl != null) {
      filledFields++;
    }

    return filledFields / totalFields;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark
        ? const Color(0x1AFFFFFF)
        : const Color(0xE6FFFFFF);

    final double progressValue = _calculateProgress();

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0F)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SETUP PROFILE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${(progressValue * 100).toInt()}% COMPLETE',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: zLogoGold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              color: zLogoGold,
              size: 18,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          Switch(
            value: isDark,
            activeThumbColor: zLogoGold,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          const SizedBox(width: 10),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3.0),
          child: Container(
            alignment: Alignment.centerLeft,
            color: Colors.white.withOpacity(0.05),
            height: 3.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: MediaQuery.of(context).size.width * progressValue,
              height: 3.0,
              decoration: const BoxDecoration(
                color: zLogoGold,
                boxShadow: [
                  BoxShadow(color: zLogoGold, blurRadius: 4, spreadRadius: 1),
                ],
              ),
            ),
          ),
        ),
      ),

      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: MeshGradientPainter(
                    animationValue: _bgAnimationController.value,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Center(
                child: Image.asset(
                  'assets/images/zhiyuan_logo.png',
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: MediaQuery.of(context).size.height * 0.6,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _entryController,
                    curve: Curves.easeIn,
                  ),
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _entryController,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.white.withOpacity(
                                isDark ? 0.08 : 0.6,
                              ),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  isDark ? 0.2 : 0.05,
                                ),
                                blurRadius: 50,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: _entryController,
                                  curve: const Interval(0.0, 0.3),
                                ),
                                child: SlideTransition(
                                  position:
                                      Tween<Offset>(
                                        begin: const Offset(0, 0.2),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: _entryController,
                                          curve: const Interval(0.0, 0.3),
                                        ),
                                      ),
                                  child: _buildProfilePic(),
                                ),
                              ),
                              const SizedBox(height: 30),
                              FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: _entryController,
                                  curve: const Interval(0.1, 0.5),
                                ),
                                child: SlideTransition(
                                  position:
                                      Tween<Offset>(
                                        begin: const Offset(0, 0.15),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: _entryController,
                                          curve: const Interval(0.1, 0.5),
                                        ),
                                      ),
                                  child: _buildCardContainer(cardBg, [
                                    _buildTextField(
                                      _usernameController,
                                      "Full Name *",
                                      Icons.person,
                                      isDark,
                                      autoCapitalize: true,
                                    ),
                                    const SizedBox(height: 15),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildGenderDropdown(isDark),
                                        ),
                                        const SizedBox(width: 15),
                                        Expanded(
                                          child: _buildTextField(
                                            _hoursController,
                                            "Req. Hours",
                                            Icons.timer,
                                            isDark,
                                            isNumber: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    _buildPhoneField(isDark),
                                    const SizedBox(height: 15),
                                    _buildTextField(
                                      _addressController,
                                      "Address",
                                      Icons.home,
                                      isDark,
                                    ),
                                  ]),
                                ),
                              ),
                              const SizedBox(height: 20),
                              FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: _entryController,
                                  curve: const Interval(0.2, 0.7),
                                ),
                                child: SlideTransition(
                                  position:
                                      Tween<Offset>(
                                        begin: const Offset(0, 0.1),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: _entryController,
                                          curve: const Interval(0.2, 0.7),
                                        ),
                                      ),
                                  child: _buildCardContainer(cardBg, [
                                    _buildAutocompleteField(
                                      controller: _schoolController,
                                      focusNode: _schoolFocusNode,
                                      label: "School",
                                      icon: Icons.school,
                                      isDark: isDark,
                                      autoCapitalize: true,
                                      suggestions: _dynamicSchoolSuggestions,
                                    ),
                                    const SizedBox(height: 15),
                                    _buildAutocompleteField(
                                      controller: _courseController,
                                      focusNode: _courseFocusNode,
                                      label: "Course",
                                      icon: Icons.book,
                                      isDark: isDark,
                                      autoCapitalize: true,
                                      suggestions: _dynamicCourseSuggestions,
                                    ),
                                  ]),
                                ),
                              ),
                              const SizedBox(height: 30),
                              FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: _entryController,
                                  curve: const Interval(0.3, 0.9),
                                ),
                                child: SlideTransition(
                                  position:
                                      Tween<Offset>(
                                        begin: const Offset(0, 0.05),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: _entryController,
                                          curve: const Interval(0.3, 0.9),
                                        ),
                                      ),
                                  child: _buildResumeBox(isDark, cardBg),
                                ),
                              ),
                              const SizedBox(height: 40),
                              FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: _entryController,
                                  curve: const Interval(0.4, 1.0),
                                ),
                                child: SlideTransition(
                                  position:
                                      Tween<Offset>(
                                        begin: const Offset(0, 0.0),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: _entryController,
                                          curve: const Interval(0.4, 1.0),
                                        ),
                                      ),
                                  child: _buildSaveButton(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePic() {
    return GestureDetector(
      onTap: () async {
        await _pickImage();
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: zLogoGold, width: 3),
          boxShadow: [
            BoxShadow(
              color: zLogoGold.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 58,
          backgroundColor: zLogoGold.withOpacity(0.1),
          backgroundImage: _selectedPhotoBytes != null
              ? MemoryImage(_selectedPhotoBytes!)
              : (_uploadedPhotoUrl != null
                    ? NetworkImage(_uploadedPhotoUrl!)
                    : null),
          child: _selectedPhotoBytes == null && _uploadedPhotoUrl == null
              ? const Icon(Icons.camera_alt, color: zLogoGold, size: 30)
              : null,
        ),
      ),
    );
  }

  Widget _buildCardContainer(Color cardBg, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildPhoneField(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        decoration: InputDecoration(
          labelText: 'Mobile Number',
          labelStyle: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 13,
          ),
          prefixText: '+63 ',
          prefixIcon: const Icon(Icons.phone, color: zLogoGold, size: 20),
          hintText: '9123456789',
          filled: true,
          fillColor: isDark ? const Color(0x1A000000) : const Color(0x80FFFFFF),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: zLogoGold, width: 1.5),
          ),
        ),
        onChanged: (value) {
          if (value.startsWith('+63')) {
            _phoneController.text = value.substring(3);
            _phoneController.selection = TextSelection.fromPosition(
              TextPosition(offset: _phoneController.text.length),
            );
          }
        },
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isDark, {
    bool isNumber = false,
    bool autoCapitalize = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        textCapitalization: autoCapitalize
            ? TextCapitalization.words
            : TextCapitalization.none,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, color: zLogoGold, size: 20),
          filled: true,
          fillColor: isDark ? const Color(0x1A000000) : const Color(0x80FFFFFF),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: zLogoGold, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    required bool isDark,
    required Iterable<String> suggestions,
    bool autoCapitalize = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: RawAutocomplete<String>(
        textEditingController: controller,
        focusNode: focusNode,
        optionsBuilder: (TextEditingValue textValue) {
          if (textValue.text.isEmpty) return const Iterable<String>.empty();
          return suggestions.where((String option) {
            return option.toLowerCase().contains(textValue.text.toLowerCase());
          });
        },
        onSelected: (String selection) {
          controller.text = selection;
          _onTextChanged();
        },
        fieldViewBuilder:
            (
              BuildContext context,
              TextEditingController fieldTextEditingController,
              FocusNode fieldFocusNode,
              VoidCallback onFieldSubmitted,
            ) {
              return TextField(
                controller: fieldTextEditingController,
                focusNode: fieldFocusNode,
                textCapitalization: autoCapitalize
                    ? TextCapitalization.words
                    : TextCapitalization.none,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(icon, color: zLogoGold, size: 20),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0x1A000000)
                      : const Color(0x80FFFFFF),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: zLogoGold, width: 1.5),
                  ),
                ),
              );
            },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(14),
              color: isDark ? const Color(0xFF1A1C20) : Colors.white,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Text(
                        option,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGenderDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGender,
          isExpanded: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          items: ['Male', 'Female', 'Other'].map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          onChanged: (String? newValue) {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedGender = newValue!;
            });
            _onTextChanged();
          },
        ),
      ),
    );
  }

  Widget _buildResumeBox(bool isDark, Color cardBg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description, color: zLogoGold, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Resume',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (_selectedResumeBytes != null || _uploadedResumeUrl != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: zLogoGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: zLogoGold.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: zLogoGold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedResumeBytes != null
                          ? 'Local PDF Selected'
                          : 'Resume Uploaded',
                      style: const TextStyle(
                        color: zLogoGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.visibility, color: zLogoGold),
                    onPressed: _handlePdfPreview,
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    await _pickResume();
                  },
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file, color: zLogoGold, size: 24),
                        SizedBox(height: 5),
                        Text(
                          'Upload Resume',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isDark) {
    Color btnColor = isDark ? zLogoGold : zOnyxBlack;
    final bool isButtonDisabled = !_isFormValid() || _isLoading;

    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isButtonDisabled)
            BoxShadow(
              color: btnColor.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isButtonDisabled ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          disabledBackgroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'FINALIZE PROFILE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}

class MeshGradientPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;

  MeshGradientPainter({required this.animationValue, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final Color color1 = isDark
        ? const Color(0xFFCC5500).withOpacity(0.6)
        : const Color(0xFFFFDAB9).withOpacity(0.8);
    final Color color2 = isDark
        ? const Color(0xFFC2A984).withOpacity(0.5)
        : const Color(0xFFEADDCA).withOpacity(0.7);

    final double w = size.width;
    final double h = size.height;

    final double x1 =
        w * 0.5 + math.sin(animationValue * math.pi * 2) * w * 0.3;
    final double y1 =
        h * 0.2 + math.cos(animationValue * math.pi * 2) * h * 0.2;
    final double x2 =
        w * 0.8 + math.cos(animationValue * math.pi * 2 * 1.5) * w * 0.2;
    final double y2 =
        h * 0.7 + math.sin(animationValue * math.pi * 2 * 1.5) * h * 0.2;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = isDark ? const Color(0xFF141619) : const Color(0xFFF8F9FA),
    );

    final Paint paint1 = Paint()
      ..shader = RadialGradient(
        colors: [color1, color1.withOpacity(0.0)],
        stops: const [0.2, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x1, y1), radius: w * 0.8))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    final Paint paint2 = Paint()
      ..shader = RadialGradient(
        colors: [color2, color2.withOpacity(0.0)],
        stops: const [0.2, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x2, y2), radius: w * 0.7))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    canvas.drawCircle(Offset(x1, y1), w * 0.8, paint1);
    canvas.drawCircle(Offset(x2, y2), w * 0.7, paint2);

    final Paint arcPaint = Paint()
      ..color = isDark
          ? Colors.white.withOpacity(0.03)
          : Colors.black.withOpacity(0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.5),
        width: w * 1.5,
        height: w * 1.5,
      ),
      0,
      math.pi * 1.5,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant MeshGradientPainter oldDelegate) => true;
}
