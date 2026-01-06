// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:hrm_app/presentation/providers/auth_provider.dart';
// import 'package:hrm_app/presentation/providers/eod_provider.dart';
// import 'package:intl/intl.dart';
// import 'package:hrm_app/core/theme/app_colors.dart';

// class EnhancedEODScreen extends StatefulWidget {
//   const EnhancedEODScreen({super.key});

//   @override
//   State<EnhancedEODScreen> createState() => _EnhancedEODScreenState();
// }

// class _EnhancedEODScreenState extends State<EnhancedEODScreen>
//     with TickerProviderStateMixin {
//   final _formKey = GlobalKey<FormState>();

//   final _projectNameController = TextEditingController();
//   final _taskDoneTodayController = TextEditingController();
//   final _challengesFacedController = TextEditingController();
//   final _studentNameController = TextEditingController();
//   final _technologyController = TextEditingController();
//   final _personWorkingOnReportController = TextEditingController();

//   final _challengesController = TextEditingController();
//   final _nextDayPlanController = TextEditingController();

//   String? _selectedTaskType;
//   double _projectStatus = 0.0;
//   DateTime? _selectedDeadline;
//   int? _timeTaken;
//   bool _reportSent = false;
//   String _reportStatus = 'Not Applicable';

//   String? _customTechnology;
//   final _customTechnologyController = TextEditingController();

//   final _projectStatusController = TextEditingController();

//   late TabController _tabController;
//   late AnimationController _fadeController;
//   late Animation<double> _fadeAnimation;
//   bool _isEditingToday = false;

//   final List<String> _taskTypes = [
//     'Assessment',
//     'Dissertation',
//     'Spare',
//     'Real Time',
//     'Local Project',
//     'Custom Text',
//   ];

//   final List<String> _technologies = [
//     'Flutter',
//     'React Native',
//     'Node.js',
//     'Python',
//     'Java',
//     'C#',
//     'PHP',
//     'Angular',
//     'Vue.js',
//     'React',
//     'Custom',
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     _fadeController = AnimationController(
//       duration: const Duration(milliseconds: 600),
//       vsync: this,
//     );
//     _fadeAnimation = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
//     _fadeController.forward();

//     _projectStatusController.text = _projectStatus.toInt().toString();

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _loadData();
//     });
//   }

//   @override
//   void dispose() {
//     _projectNameController.dispose();
//     _taskDoneTodayController.dispose();
//     _challengesFacedController.dispose();
//     _studentNameController.dispose();
//     _technologyController.dispose();
//     _personWorkingOnReportController.dispose();
//     _customTechnologyController.dispose();
//     _projectStatusController.dispose();
//     _challengesController.dispose();
//     _nextDayPlanController.dispose();
//     _tabController.dispose();
//     _fadeController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadData() async {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final eodProvider = Provider.of<EODProvider>(context, listen: false);
//     final token = authProvider.token;

//     if (token == null) return;

//     await Future.wait([
//       eodProvider.loadTodayEOD(token),
//       eodProvider.loadMyEODs(token),
//       eodProvider.loadEODStats(token),
//     ]);

//     if (eodProvider.todayEOD != null) {
//       _populateForm(eodProvider.todayEOD!);
//     }
//   }

//   void _populateForm(Map<String, dynamic> eod) {
//     _projectNameController.text = eod['projectName'] ?? '';
//     _taskDoneTodayController.text = eod['taskDoneToday'] ?? '';
//     _challengesFacedController.text = eod['challengesFaced'] ?? '';
//     _studentNameController.text = eod['studentName'] ?? '';
//     _technologyController.text = eod['technology'] ?? '';
//     _personWorkingOnReportController.text = eod['personWorkingOnReport'] ?? '';

//     _selectedTaskType = eod['taskType'];
//     _projectStatus = (eod['projectStatus'] ?? 0.0).toDouble();
//     _projectStatusController.text = _projectStatus.toInt().toString();
//     _timeTaken = eod['daysTaken'] ?? 0;
//     _reportSent = eod['reportSent'] ?? false;
//     _reportStatus = eod['reportStatus'] ?? 'Not Applicable';

//     if (eod['deadline'] != null) {
//       _selectedDeadline = DateTime.parse(eod['deadline']);
//     }

//     _challengesController.text = eod['challenges'] ?? '';
//     _nextDayPlanController.text = eod['nextDayPlan'] ?? '';
//   }

//   void _clearForm() {
//     _projectNameController.clear();
//     _taskDoneTodayController.clear();
//     _challengesFacedController.clear();
//     _studentNameController.clear();
//     _technologyController.clear();
//     _personWorkingOnReportController.clear();
//     _customTechnologyController.clear();
//     _projectStatusController.clear();
//     _challengesController.clear();
//     _nextDayPlanController.clear();

//     setState(() {
//       _selectedTaskType = null;
//       _projectStatus = 0.0;
//       _selectedDeadline = null;
//       _timeTaken = 0;
//       _reportSent = false;
//       _reportStatus = 'Not Applicable';
//       _customTechnology = null;
//     });
//   }

//   Future<void> _submitOrUpdateEOD() async {
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }

//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final eodProvider = Provider.of<EODProvider>(context, listen: false);
//     final token = authProvider.token;

//     if (token == null) {
//       return;
//     }

//     final eodData = {
//       'projectName': _projectNameController.text.trim(),
//       'taskDoneToday': _taskDoneTodayController.text.trim(),
//       'challengesFaced': _challengesFacedController.text.trim(),
//       'studentName': _studentNameController.text.trim(),
//       'technology': _customTechnology ?? _technologyController.text.trim(),
//       'taskType': _selectedTaskType,
//       'projectStatus': _projectStatus,
//       'deadline': _selectedDeadline?.toIso8601String(),
//       'daysTaken': _timeTaken,
//       'reportSent': _reportSent,
//       'personWorkingOnReport': _personWorkingOnReportController.text.trim(),
//       'reportStatus': _reportStatus,

//       'project': _projectNameController.text.trim().isNotEmpty
//           ? _projectNameController.text.trim()
//           : 'Project work',
//       'tasksCompleted': _taskDoneTodayController.text.trim().isNotEmpty
//           ? _taskDoneTodayController.text.trim()
//           : 'Tasks completed today',
//       'challenges': _challengesController.text.trim().isNotEmpty
//           ? _challengesController.text.trim()
//           : (_challengesFacedController.text.trim().isNotEmpty
//                 ? _challengesFacedController.text.trim()
//                 : 'No challenges'),
//       'nextDayPlan': _nextDayPlanController.text.trim().isNotEmpty
//           ? _nextDayPlanController.text.trim()
//           : 'Work on upcoming tasks',
//     };

//     bool success;
//     if (eodProvider.todayEOD != null && _isEditingToday) {
//       success = await eodProvider.updateEOD(
//         token,
//         eodProvider.todayEOD!['_id'],
//         eodData,
//         context: context,
//       );
//     } else {
//       success = await eodProvider.createEOD(token, eodData, context: context);
//     }

//     if (success) {
//       _clearForm();
//       setState(() {
//         _isEditingToday = false;
//       });
//       _showSuccessDialog(
//         eodProvider.todayEOD != null && _isEditingToday
//             ? 'EOD updated successfully!'
//             : 'EOD submitted successfully!',
//       );
//       await _loadData();
//     } else {
//       if (eodProvider.error != null) {
//         _showErrorDialog('Failed to submit EOD', eodProvider.error!);
//       } else {
//         _showErrorDialog('Failed to submit EOD', 'An unknown error occurred');
//       }
//     }
//   }

//   Future<void> _deleteEOD(String eodId) async {
//     final confirmed = await _showConfirmDialog(
//       'Delete EOD',
//       'Are you sure you want to delete this EOD? This action cannot be undone.',
//     );

//     if (!confirmed) return;

//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final eodProvider = Provider.of<EODProvider>(context, listen: false);
//     final token = authProvider.token;

//     if (token == null) return;

//     final success = await eodProvider.deleteEOD(token, eodId, context: context);

//     if (success) {
//       _clearForm();
//       setState(() {
//         _isEditingToday = false;
//       });
//       _showSuccessDialog('EOD deleted successfully!');
//       await _loadData();
//     }
//   }

//   Future<bool> _showConfirmDialog(String title, String message) async {
//     return await showDialog<bool>(
//           context: context,
//           barrierDismissible: false,
//           builder: (BuildContext context) {
//             return AlertDialog(
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               title: Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.edgeText,
//                 ),
//               ),
//               content: Text(
//                 message,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   color: AppColors.edgeTextSecondary,
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.of(context).pop(false),
//                   child: const Text(
//                     'Cancel',
//                     style: TextStyle(color: AppColors.edgeTextSecondary),
//                   ),
//                 ),
//                 ElevatedButton(
//                   onPressed: () => Navigator.of(context).pop(true),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.edgeError,
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   child: const Text('Delete'),
//                 ),
//               ],
//             );
//           },
//         ) ??
//         false;
//   }

//   void _showSuccessDialog(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: AppColors.edgeSuccess,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//       ),
//     );
//   }

//   void _showErrorDialog(String title, String message) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           title: Row(
//             children: [
//               const Icon(
//                 Icons.error_outline,
//                 color: AppColors.edgeError,
//                 size: 24,
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.edgeText,
//                 ),
//               ),
//             ],
//           ),
//           content: Text(
//             message,
//             style: const TextStyle(
//               fontSize: 14,
//               color: AppColors.edgeTextSecondary,
//             ),
//           ),
//           actions: [
//             ElevatedButton(
//               onPressed: () => Navigator.of(context).pop(),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: AppColors.edgeError,
//                 foregroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               child: const Text('OK'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Future<void> _selectDeadline() async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedDeadline ?? DateTime.now(),
//       firstDate: DateTime.now(),
//       lastDate: DateTime.now().add(const Duration(days: 365)),
//       builder: (context, child) {
//         return Theme(
//           data: Theme.of(context).copyWith(
//             colorScheme: const ColorScheme.light(
//               primary: AppColors.edgePrimary,
//               onPrimary: Colors.white,
//               surface: AppColors.edgeSurface,
//               onSurface: AppColors.edgeText,
//             ),
//           ),
//           child: child!,
//         );
//       },
//     );
//     if (picked != null && picked != _selectedDeadline) {
//       setState(() {
//         _selectedDeadline = picked;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.edgeBackground,
//       body: Column(
//         children: [
//           Container(
//             margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
//             decoration: BoxDecoration(
//               color: AppColors.edgeSurface,
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(
//                 color: AppColors.edgeDivider.withValues(alpha: 0.2),
//                 width: 1,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: AppColors.edgeText.withValues(alpha: 0.05),
//                   blurRadius: 8,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: TabBar(
//               controller: _tabController,
//               labelColor: AppColors.edgePrimary,
//               unselectedLabelColor: AppColors.edgeTextSecondary,
//               indicatorColor: Colors.transparent,
//               indicatorWeight: 0,
//               indicator: BoxDecoration(
//                 color: AppColors.edgePrimary.withValues(alpha: 0.1),
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(
//                   color: AppColors.edgePrimary.withValues(alpha: 0.2),
//                   width: 1,
//                 ),
//               ),
//               indicatorSize: TabBarIndicatorSize.tab,
//               labelStyle: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 letterSpacing: -0.2,
//               ),
//               unselectedLabelStyle: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w500,
//                 letterSpacing: -0.2,
//               ),
//               tabs: const [
//                 Tab(
//                   child: Padding(
//                     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(Icons.today_rounded, size: 18),
//                         SizedBox(width: 8),
//                         Text('Today'),
//                       ],
//                     ),
//                   ),
//                 ),
//                 Tab(
//                   child: Padding(
//                     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(Icons.history_rounded, size: 18),
//                         SizedBox(width: 8),
//                         Text('History'),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           Expanded(
//             child: TabBarView(
//               controller: _tabController,
//               children: [_buildTodayTab(), _buildHistoryTab()],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTodayTab() {
//     return Consumer<EODProvider>(
//       builder: (context, eodProvider, child) {
//         if (eodProvider.isLoading) {
//           return const Center(
//             child: CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(AppColors.edgePrimary),
//             ),
//           );
//         }

//         return SingleChildScrollView(
//           padding: const EdgeInsets.all(20),
//           child: FadeTransition(
//             opacity: _fadeAnimation,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _buildStatsCard(eodProvider),

//                 Form(
//                   key: _formKey,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(20),
//                         decoration: BoxDecoration(
//                           color: AppColors.edgeSurface,
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: AppColors.edgeBorder),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withValues(alpha: 0.05),
//                               blurRadius: 10,
//                               offset: const Offset(0, 2),
//                             ),
//                           ],
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             _buildInlineField(
//                               icon: Icons.calendar_today_outlined,
//                               label: 'Date',
//                               child: Text(
//                                 DateFormat(
//                                   'EEEE, MMMM d, y',
//                                 ).format(DateTime.now()),
//                                 style: const TextStyle(
//                                   fontSize: 16,
//                                   color: AppColors.edgeText,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ),
//                             const Divider(height: 32),

//                             _buildInlineTextField(
//                               controller: _projectNameController,
//                               label: 'Project Name',
//                               hint: 'Enter project name',
//                               icon: Icons.folder_outlined,
//                               isRequired: true,
//                             ),
//                             const Divider(height: 32),

//                             _buildInlineTextField(
//                               controller: _taskDoneTodayController,
//                               label: 'Task Done Today',
//                               hint:
//                                   'Describe the task you completed today (minimum 50 words)',
//                               icon: Icons.description_outlined,
//                               isRequired: true,
//                               maxLines: 5,
//                               minWords: 50,
//                             ),
//                             const Divider(height: 32),

//                             _buildInlineTextField(
//                               controller: _challengesFacedController,
//                               label: 'Challenges Faced / IF ANY',
//                               hint:
//                                   'Describe any challenges you faced during the task',
//                               icon: Icons.warning_outlined,
//                               isRequired: false,
//                               maxLines: 3,
//                             ),
//                             const Divider(height: 32),

//                             _buildInlineTextField(
//                               controller: _studentNameController,
//                               label: 'Student Name',
//                               hint: 'Enter student name and university',
//                               icon: Icons.person_outline_rounded,
//                               isRequired: false,
//                             ),
//                             const Divider(height: 32),

//                             _buildInlineTechnologyField(),
//                             const Divider(height: 32),

//                             _buildInlineDropdownField(
//                               label: 'Task Type',
//                               value: _selectedTaskType,
//                               items: _taskTypes,
//                               onChanged: (value) {
//                                 setState(() {
//                                   _selectedTaskType = value;
//                                 });
//                               },
//                               isRequired: true,
//                             ),
//                             const Divider(height: 32),

//                             _buildInlineProjectStatusField(),
//                             const Divider(height: 32),

//                             _buildInlineDeadlineField(),
//                             const Divider(height: 32),

//                             _buildInlineDaysTakenField(),
//                             const Divider(height: 32),

//                             _buildInlineToggleField(
//                               label: 'Report Sent',
//                               value: _reportSent,
//                               onChanged: (value) {
//                                 setState(() {
//                                   _reportSent = value;
//                                 });
//                               },
//                               isRequired: false,
//                             ),
//                             const Divider(height: 32),

//                             _buildInlineTextField(
//                               controller: _personWorkingOnReportController,
//                               label: 'Person Working on Report',
//                               hint: 'Who is working on the report?',
//                               icon: Icons.assignment_outlined,
//                               isRequired: false,
//                             ),
//                             const Divider(height: 32),

//                             _buildInlineDropdownField(
//                               label: 'Report Status',
//                               value: _reportStatus,
//                               items: [
//                                 'Not Applicable',
//                                 'Pending',
//                                 'In Progress',
//                                 'Completed',
//                               ],
//                               onChanged: (value) {
//                                 setState(() {
//                                   _reportStatus = value ?? 'Not Applicable';
//                                 });
//                               },
//                               isRequired: true,
//                             ),
//                             const Divider(height: 32),

//                             _buildInlineTextField(
//                               controller: _nextDayPlanController,
//                               label: 'Next Day Plan',
//                               hint: 'What is your plan for tomorrow?',
//                               icon: Icons.schedule_outlined,
//                               isRequired: false,
//                               maxLines: 3,
//                             ),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 32),

//                       _buildActionButtons(eodProvider),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildStatsCard(EODProvider eodProvider) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 20),
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//       decoration: BoxDecoration(
//         color: AppColors.edgeSurface,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.05),
//             blurRadius: 10,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           if (eodProvider.eodStats != null) ...[
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildStatItem(
//                     'Total EODs',
//                     '${eodProvider.eodStats!['totalEODs'] ?? 0}',
//                     Icons.description_outlined,
//                     AppColors.edgePrimary,
//                   ),
//                 ),
//                 Expanded(
//                   child: _buildStatItem(
//                     'This Month',
//                     '${eodProvider.eodStats!['thisMonth'] ?? 0}',
//                     Icons.calendar_month_outlined,
//                     AppColors.edgeAccent,
//                   ),
//                 ),
//               ],
//             ),
//           ] else
//             const Text(
//               'No statistics available',
//               style: TextStyle(
//                 color: AppColors.edgeTextSecondary,
//                 fontSize: 14,
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatItem(
//     String label,
//     String value,
//     IconData icon,
//     Color color,
//   ) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Icon(icon, size: 16, color: color),
//             const SizedBox(width: 6),
//             Text(
//               label,
//               style: const TextStyle(
//                 fontSize: 12,
//                 color: AppColors.edgeTextSecondary,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 4),
//         Text(
//           value,
//           style: TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.w700,
//             color: color,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildSectionHeader(
//     String title,
//     String subtitle,
//     IconData icon,
//     Color color,
//   ) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.05),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color.withValues(alpha: 0.2)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: color.withValues(alpha: 0.1),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Icon(icon, color: color, size: 20),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                     color: color,
//                   ),
//                 ),
//                 Text(
//                   subtitle,
//                   style: const TextStyle(
//                     fontSize: 12,
//                     color: AppColors.edgeTextSecondary,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDateField() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.edgeSurface,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.edgeBorder),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Row(
//             children: [
//               Icon(
//                 Icons.calendar_today_outlined,
//                 color: AppColors.edgePrimary,
//                 size: 20,
//               ),
//               SizedBox(width: 8),
//               Text(
//                 'Date',
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.edgeText,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Text(
//             DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
//             style: const TextStyle(
//               fontSize: 16,
//               color: AppColors.edgeText,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String label,
//     required String hint,
//     required IconData icon,
//     required bool isRequired,
//     int maxLines = 1,
//     int? minWords,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.edgeSurface,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.edgeBorder),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: AppColors.edgePrimary, size: 20),
//               const SizedBox(width: 8),
//               Text(
//                 label,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.edgeText,
//                 ),
//               ),
//               if (isRequired)
//                 const Text(
//                   ' *',
//                   style: TextStyle(color: AppColors.edgeError, fontSize: 14),
//                 ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           TextFormField(
//             controller: controller,
//             maxLines: maxLines,
//             style: const TextStyle(fontSize: 16, color: AppColors.edgeText),
//             decoration: InputDecoration(
//               hintText: hint,
//               hintStyle: const TextStyle(
//                 color: AppColors.edgeTextSecondary,
//                 fontSize: 14,
//               ),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: const BorderSide(color: AppColors.edgeBorder),
//               ),
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: const BorderSide(color: AppColors.edgeBorder),
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: const BorderSide(
//                   color: AppColors.edgePrimary,
//                   width: 2,
//                 ),
//               ),
//               contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 12,
//                 vertical: 12,
//               ),
//             ),
//             validator: isRequired
//                 ? (value) {
//                     if (value == null || value.trim().isEmpty) {
//                       return 'This field is required';
//                     }
//                     if (minWords != null) {
//                       final wordCount = value
//                           .trim()
//                           .split(RegExp(r'\s+'))
//                           .length;
//                       if (wordCount < minWords) {
//                         return 'Minimum $minWords words required (current: $wordCount words)';
//                       }
//                     }
//                     return null;
//                   }
//                 : (value) {
//                     if (minWords != null &&
//                         value != null &&
//                         value.trim().isNotEmpty) {
//                       final wordCount = value
//                           .trim()
//                           .split(RegExp(r'\s+'))
//                           .length;
//                       if (wordCount < minWords) {
//                         return 'Minimum $minWords words required (current: $wordCount words)';
//                       }
//                     }
//                     return null;
//                   },
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDropdownField({
//     required String label,
//     required String? value,
//     required List<String> items,
//     required Function(String?) onChanged,
//     required bool isRequired,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.edgeSurface,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.edgeBorder),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Icon(
//                 Icons.arrow_drop_down_outlined,
//                 color: AppColors.edgePrimary,
//                 size: 20,
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 label,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.edgeText,
//                 ),
//               ),
//               if (isRequired)
//                 const Text(
//                   ' *',
//                   style: TextStyle(color: AppColors.edgeError, fontSize: 14),
//                 ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           DropdownButtonFormField<String>(
//             initialValue: value,
//             items: items.map((item) {
//               return DropdownMenuItem<String>(value: item, child: Text(item));
//             }).toList(),
//             onChanged: onChanged,
//             decoration: InputDecoration(
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: const BorderSide(color: AppColors.edgeBorder),
//               ),
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: const BorderSide(color: AppColors.edgeBorder),
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: const BorderSide(
//                   color: AppColors.edgePrimary,
//                   width: 2,
//                 ),
//               ),
//               contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 12,
//                 vertical: 12,
//               ),
//             ),
//             validator: isRequired
//                 ? (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please select an option';
//                     }
//                     return null;
//                   }
//                 : null,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildToggleField({
//     required String label,
//     required bool value,
//     required Function(bool) onChanged,
//     required bool isRequired,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.edgeSurface,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.edgeBorder),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Icon(
//                 Icons.toggle_on_outlined,
//                 color: AppColors.edgePrimary,
//                 size: 20,
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 label,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.edgeText,
//                 ),
//               ),
//               if (isRequired)
//                 const Text(
//                   ' *',
//                   style: TextStyle(color: AppColors.edgeError, fontSize: 14),
//                 ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Switch(
//                 value: value,
//                 onChanged: onChanged,
//                 activeThumbColor: AppColors.edgePrimary,
//                 inactiveThumbColor: AppColors.edgeTextSecondary,
//                 inactiveTrackColor: AppColors.edgeBorder,
//               ),
//               const SizedBox(width: 12),
//               Text(
//                 value ? 'Yes' : 'No',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                   color: value
//                       ? AppColors.edgePrimary
//                       : AppColors.edgeTextSecondary,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTechnologyField() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.edgeSurface,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.edgeBorder),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Row(
//             children: [
//               Icon(Icons.code_outlined, color: AppColors.edgePrimary, size: 20),
//               SizedBox(width: 8),
//               Text(
//                 'Technology',
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.edgeText,
//                 ),
//               ),
//               Text(
//                 ' *',
//                 style: TextStyle(color: AppColors.edgeError, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           DropdownButtonFormField<String>(
//             initialValue: _technologyController.text.isEmpty
//                 ? null
//                 : _technologyController.text,
//             items: _technologies.map((tech) {
//               return DropdownMenuItem<String>(value: tech, child: Text(tech));
//             }).toList(),
//             onChanged: (value) {
//               setState(() {
//                 _technologyController.text = value ?? '';
//                 _customTechnology = null;
//               });
//             },
//             decoration: InputDecoration(
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: const BorderSide(color: AppColors.edgeBorder),
//               ),
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: const BorderSide(color: AppColors.edgeBorder),
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: const BorderSide(
//                   color: AppColors.edgePrimary,
//                   width: 2,
//                 ),
//               ),
//               contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 12,
//                 vertical: 12,
//               ),
//             ),
//             validator: (value) {
//               if (_customTechnology == null &&
//                   (value == null || value.isEmpty)) {
//                 return 'Please select a technology';
//               }
//               return null;
//             },
//           ),
//           if (_technologyController.text == 'Custom') ...[
//             const SizedBox(height: 12),
//             TextFormField(
//               controller: _customTechnologyController,
//               decoration: const InputDecoration(
//                 labelText: 'Custom Technology',
//                 border: OutlineInputBorder(),
//                 contentPadding: EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 12,
//                 ),
//               ),
//               onChanged: (value) {
//                 setState(() {
//                   _customTechnology = value;
//                 });
//               },
//               validator: _technologyController.text == 'Custom'
//                   ? (value) {
//                       if (value == null || value.trim().isEmpty) {
//                         return 'Please enter custom technology';
//                       }
//                       return null;
//                     }
//                   : null,
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildProjectStatusField() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.edgeSurface,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.edgeBorder),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Row(
//             children: [
//               Icon(
//                 Icons.percent_outlined,
//                 color: AppColors.edgePrimary,
//                 size: 20,
//               ),
//               SizedBox(width: 8),
//               Text(
//                 'Status (%)',
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.edgeText,
//                 ),
//               ),
//               Text(
//                 ' *',
//                 style: TextStyle(color: AppColors.edgeError, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Expanded(
//                 child: TextFormField(
//                   controller: _projectStatusController,
//                   keyboardType: TextInputType.number,
//                   decoration: const InputDecoration(
//                     labelText: 'Percentage',
//                     border: OutlineInputBorder(),
//                     contentPadding: EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 8,
//                     ),
//                   ),
//                   onChanged: (value) {
//                     final parsed = double.tryParse(value);
//                     if (parsed != null && parsed >= 0 && parsed <= 100) {
//                       setState(() {
//                         _projectStatus = parsed;
//                       });
//                     }
//                   },
//                   validator: (value) {
//                     if (value == null || value.trim().isEmpty) {
//                       return 'Status is required';
//                     }
//                     final parsed = double.tryParse(value);
//                     if (parsed == null || parsed < 0 || parsed > 100) {
//                       return 'Please enter a valid percentage (0-100)';
//                     }
//                     return null;
//                   },
//                 ),
//               ),
//               const SizedBox(width: 16),
//               Text(
//                 '${_projectStatus.toInt()}%',
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.edgePrimary,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Slider(
//             value: _projectStatus,
//             min: 0,
//             max: 100,
//             divisions: 100,
//             onChanged: (value) {
//               setState(() {
//                 _projectStatus = value;
//                 _projectStatusController.text = value.toInt().toString();
//               });
//             },
//             activeColor: AppColors.edgePrimary,
//             inactiveColor: AppColors.edgeBorder,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDeadlineField() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.edgeSurface,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.edgeBorder),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Row(
//             children: [
//               Icon(
//                 Icons.event_outlined,
//                 color: AppColors.edgePrimary,
//                 size: 20,
//               ),
//               SizedBox(width: 8),
//               Text(
//                 'Deadline',
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.edgeText,
//                 ),
//               ),
//               Text(
//                 ' *',
//                 style: TextStyle(color: AppColors.edgeError, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           InkWell(
//             onTap: _selectDeadline,
//             child: Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 border: Border.all(color: AppColors.edgeBorder),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       _selectedDeadline != null
//                           ? DateFormat('MMM d, y').format(_selectedDeadline!)
//                           : 'Select deadline',
//                       style: TextStyle(
//                         fontSize: 16,
//                         color: _selectedDeadline != null
//                             ? AppColors.edgeText
//                             : AppColors.edgeTextSecondary,
//                       ),
//                     ),
//                   ),
//                   const Icon(
//                     Icons.calendar_today,
//                     color: AppColors.edgePrimary,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDaysTakenField() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.edgeSurface,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.edgeBorder),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Row(
//             children: [
//               Icon(
//                 Icons.calendar_today_outlined,
//                 color: AppColors.edgePrimary,
//                 size: 20,
//               ),
//               SizedBox(width: 8),
//               Text(
//                 'Days Taken',
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.edgeText,
//                 ),
//               ),
//               Text(
//                 ' *',
//                 style: TextStyle(color: AppColors.edgeError, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               IconButton(
//                 onPressed: (_timeTaken != null && _timeTaken! > 0)
//                     ? () {
//                         setState(() {
//                           _timeTaken = _timeTaken! - 1;
//                         });
//                       }
//                     : null,
//                 icon: const Icon(Icons.remove),
//               ),
//               Container(
//                 width: 60,
//                 padding: const EdgeInsets.symmetric(vertical: 8),
//                 decoration: BoxDecoration(
//                   border: Border.all(color: AppColors.edgeBorder),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(
//                   '${_timeTaken ?? 0}',
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                     color: AppColors.edgeText,
//                   ),
//                 ),
//               ),
//               IconButton(
//                 onPressed: () {
//                   setState(() {
//                     _timeTaken = (_timeTaken ?? 0) + 1;
//                   });
//                 },
//                 icon: const Icon(Icons.add),
//               ),
//               const SizedBox(width: 16),
//               const Text(
//                 'days',
//                 style: TextStyle(
//                   fontSize: 14,
//                   color: AppColors.edgeTextSecondary,
//                 ),
//               ),
//             ],
//           ),
//           if (_selectedDeadline != null) ...[
//             const SizedBox(height: 8),
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: AppColors.edgePrimary.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(6),
//               ),
//               child: Row(
//                 children: [
//                   const Icon(
//                     Icons.info_outline,
//                     size: 16,
//                     color: AppColors.edgePrimary,
//                   ),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'Deadline: ${DateFormat('MMM d, y').format(_selectedDeadline!)}',
//                       style: const TextStyle(
//                         fontSize: 12,
//                         color: AppColors.edgePrimary,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildActionButtons(EODProvider eodProvider) {
//     return Row(
//       children: [
//         Expanded(
//           child: OutlinedButton(
//             onPressed: eodProvider.isSubmitting
//                 ? null
//                 : () {
//                     _clearForm();
//                   },
//             style: OutlinedButton.styleFrom(
//               padding: const EdgeInsets.symmetric(vertical: 16),
//               side: const BorderSide(color: AppColors.edgeBorder),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             child: const Text(
//               'Clear Form',
//               style: TextStyle(
//                 color: AppColors.edgeTextSecondary,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(width: 16),
//         Expanded(
//           flex: 2,
//           child: ElevatedButton(
//             onPressed: eodProvider.isSubmitting ? null : _submitOrUpdateEOD,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.edgePrimary,
//               foregroundColor: Colors.white,
//               padding: const EdgeInsets.symmetric(vertical: 16),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             child: eodProvider.isSubmitting
//                 ? const SizedBox(
//                     height: 20,
//                     width: 20,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2,
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                     ),
//                   )
//                 : Text(
//                     eodProvider.todayEOD != null && _isEditingToday
//                         ? 'Update EOD'
//                         : 'Submit EOD',
//                     style: const TextStyle(fontWeight: FontWeight.w600),
//                   ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildHistoryTab() {
//     return Consumer<EODProvider>(
//       builder: (context, eodProvider, child) {
//         if (eodProvider.isLoading) {
//           return const Center(
//             child: CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(AppColors.edgePrimary),
//             ),
//           );
//         }

//         if (eodProvider.myEODs.isEmpty) {
//           return Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(
//                   Icons.description_outlined,
//                   size: 64,
//                   color: Colors.grey[400],
//                 ),
//                 const SizedBox(height: 16),
//                 Text(
//                   'No EOD entries found',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w600,
//                     color: Colors.grey[600],
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   'Your EOD history will appear here',
//                   style: TextStyle(fontSize: 14, color: Colors.grey[500]),
//                 ),
//               ],
//             ),
//           );
//         }

//         return ListView.builder(
//           padding: const EdgeInsets.all(20),
//           itemCount: eodProvider.myEODs.length,
//           itemBuilder: (context, index) {
//             final eod = eodProvider.myEODs[index];
//             return _buildEODHistoryCard(eod);
//           },
//         );
//       },
//     );
//   }

//   Widget _buildEODHistoryCard(Map<String, dynamic> eod) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 16),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.edgeSurface,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: AppColors.edgePrimary.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: const Icon(
//                   Icons.description_outlined,
//                   color: AppColors.edgePrimary,
//                   size: 16,
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Text(
//                   eod['projectName'] ?? eod['project'] ?? 'EOD Entry',
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                     color: AppColors.edgeText,
//                   ),
//                 ),
//               ),
//               Text(
//                 DateFormat('MMM d, y').format(DateTime.parse(eod['date'])),
//                 style: const TextStyle(
//                   fontSize: 12,
//                   color: AppColors.edgeTextSecondary,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           if (eod['studentName'] != null) ...[
//             _buildInfoRow('Student/Client', eod['studentName']),
//           ],
//           if (eod['technology'] != null) ...[
//             _buildInfoRow('Technology', eod['technology']),
//           ],
//           if (eod['taskType'] != null) ...[
//             _buildInfoRow('Task Type', eod['taskType']),
//           ],
//           if (eod['projectStatus'] != null) ...[
//             _buildInfoRow('Status', '${eod['projectStatus'].toInt()}%'),
//           ],
//           if (eod['daysTaken'] != null) ...[
//             _buildInfoRow('Days Taken', '${eod['daysTaken']} days'),
//           ],
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Expanded(
//                 child: OutlinedButton(
//                   onPressed: () {},
//                   style: OutlinedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 8),
//                     side: const BorderSide(color: AppColors.edgeBorder),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                   ),
//                   child: const Text(
//                     'Edit',
//                     style: TextStyle(
//                       color: AppColors.edgeTextSecondary,
//                       fontSize: 12,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: OutlinedButton(
//                   onPressed: () {
//                     _deleteEOD(eod['_id']);
//                   },
//                   style: OutlinedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 8),
//                     side: const BorderSide(color: AppColors.edgeError),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                   ),
//                   child: const Text(
//                     'Delete',
//                     style: TextStyle(color: AppColors.edgeError, fontSize: 12),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildInfoRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 4),
//       child: Row(
//         children: [
//           Text(
//             '$label: ',
//             style: const TextStyle(
//               fontSize: 12,
//               color: AppColors.edgeTextSecondary,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           Expanded(
//             child: Text(
//               value,
//               style: const TextStyle(fontSize: 12, color: AppColors.edgeText),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildInlineField({
//     required IconData icon,
//     required String label,
//     required Widget child,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Icon(icon, color: AppColors.edgePrimary, size: 18),
//             const SizedBox(width: 8),
//             Text(
//               label,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.edgeText,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         child,
//       ],
//     );
//   }

//   Widget _buildInlineTextField({
//     required TextEditingController controller,
//     required String label,
//     required String hint,
//     required IconData icon,
//     required bool isRequired,
//     int maxLines = 1,
//     int? minWords,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Icon(icon, color: AppColors.edgePrimary, size: 18),
//             const SizedBox(width: 8),
//             Text(
//               label,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.edgeText,
//               ),
//             ),
//             if (isRequired)
//               const Text(
//                 ' *',
//                 style: TextStyle(color: AppColors.edgeError, fontSize: 14),
//               ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         TextFormField(
//           controller: controller,
//           maxLines: maxLines,
//           style: const TextStyle(fontSize: 15, color: AppColors.edgeText),
//           decoration: InputDecoration(
//             hintText: hint,
//             hintStyle: const TextStyle(
//               fontSize: 15,
//               color: AppColors.edgeTextSecondary,
//             ),
//             filled: true,
//             fillColor: AppColors.edgeBackground,
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8),
//               borderSide: BorderSide.none,
//             ),
//             contentPadding: const EdgeInsets.symmetric(
//               horizontal: 12,
//               vertical: 12,
//             ),
//           ),
//           validator: (value) {
//             if (isRequired && (value == null || value.trim().isEmpty)) {
//               return '$label is required';
//             }
//             if (minWords != null && value != null) {
//               final wordCount = value.trim().split(RegExp(r'\s+')).length;
//               if (wordCount < minWords) {
//                 return 'Please enter at least $minWords words (current: $wordCount)';
//               }
//             }
//             return null;
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildInlineTechnologyField() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Row(
//           children: [
//             Icon(Icons.code_outlined, color: AppColors.edgePrimary, size: 18),
//             SizedBox(width: 8),
//             Text(
//               'Technology',
//               style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.edgeText,
//               ),
//             ),
//             Text(
//               ' *',
//               style: TextStyle(color: AppColors.edgeError, fontSize: 14),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         DropdownButtonFormField<String>(
//           initialValue:
//               _customTechnology ??
//               (_technologies.contains(_technologyController.text)
//                   ? _technologyController.text
//                   : null),
//           decoration: InputDecoration(
//             hintText: 'Select technology',
//             filled: true,
//             fillColor: AppColors.edgeBackground,
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8),
//               borderSide: BorderSide.none,
//             ),
//             contentPadding: const EdgeInsets.symmetric(
//               horizontal: 12,
//               vertical: 12,
//             ),
//           ),
//           items: _technologies
//               .map((tech) => DropdownMenuItem(value: tech, child: Text(tech)))
//               .toList(),
//           onChanged: (value) {
//             setState(() {
//               if (value == 'Custom') {
//                 _customTechnology = null;
//               } else {
//                 _technologyController.text = value ?? '';
//                 _customTechnology = null;
//               }
//             });
//           },
//         ),
//         if (_customTechnology == null &&
//             _technologyController.text == 'Custom') ...[
//           const SizedBox(height: 8),
//           TextFormField(
//             controller: _customTechnologyController,
//             decoration: InputDecoration(
//               hintText: 'Enter custom technology',
//               filled: true,
//               fillColor: AppColors.edgeBackground,
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: BorderSide.none,
//               ),
//               contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 12,
//                 vertical: 12,
//               ),
//             ),
//             onChanged: (value) {
//               setState(() {
//                 _customTechnology = value;
//               });
//             },
//           ),
//         ],
//       ],
//     );
//   }

//   Widget _buildInlineDropdownField({
//     required String label,
//     required String? value,
//     required List<String> items,
//     required ValueChanged<String?> onChanged,
//     required bool isRequired,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             const Icon(
//               Icons.list_outlined,
//               color: AppColors.edgePrimary,
//               size: 18,
//             ),
//             const SizedBox(width: 8),
//             Text(
//               label,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.edgeText,
//               ),
//             ),
//             if (isRequired)
//               const Text(
//                 ' *',
//                 style: TextStyle(color: AppColors.edgeError, fontSize: 14),
//               ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         DropdownButtonFormField<String>(
//           initialValue: value,
//           decoration: InputDecoration(
//             hintText: 'Select $label',
//             filled: true,
//             fillColor: AppColors.edgeBackground,
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8),
//               borderSide: BorderSide.none,
//             ),
//             contentPadding: const EdgeInsets.symmetric(
//               horizontal: 12,
//               vertical: 12,
//             ),
//           ),
//           items: items
//               .map((item) => DropdownMenuItem(value: item, child: Text(item)))
//               .toList(),
//           onChanged: onChanged,
//           validator: (val) {
//             if (isRequired && val == null) {
//               return '$label is required';
//             }
//             return null;
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildInlineProjectStatusField() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             const Icon(
//               Icons.trending_up_outlined,
//               color: AppColors.edgePrimary,
//               size: 18,
//             ),
//             const SizedBox(width: 8),
//             const Text(
//               'Project Status',
//               style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.edgeText,
//               ),
//             ),
//             const Text(
//               ' *',
//               style: TextStyle(color: AppColors.edgeError, fontSize: 14),
//             ),
//             const Spacer(),
//             Text(
//               '${_projectStatus.toInt()}%',
//               style: const TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: AppColors.edgePrimary,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         Slider(
//           value: _projectStatus,
//           min: 0,
//           max: 100,
//           divisions: 100,
//           activeColor: AppColors.edgePrimary,
//           onChanged: (value) {
//             setState(() {
//               _projectStatus = value;
//               _projectStatusController.text = value.toInt().toString();
//             });
//           },
//         ),
//         const SizedBox(height: 8),
//         TextFormField(
//           controller: _projectStatusController,
//           keyboardType: TextInputType.number,
//           decoration: InputDecoration(
//             hintText: 'Or enter percentage',
//             filled: true,
//             fillColor: AppColors.edgeBackground,
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8),
//               borderSide: BorderSide.none,
//             ),
//             contentPadding: const EdgeInsets.symmetric(
//               horizontal: 12,
//               vertical: 12,
//             ),
//           ),
//           onChanged: (value) {
//             final parsed = double.tryParse(value);
//             if (parsed != null && parsed >= 0 && parsed <= 100) {
//               setState(() {
//                 _projectStatus = parsed;
//               });
//             }
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildInlineDeadlineField() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Row(
//           children: [
//             Icon(Icons.event_outlined, color: AppColors.edgePrimary, size: 18),
//             SizedBox(width: 8),
//             Text(
//               'Deadline',
//               style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.edgeText,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         InkWell(
//           onTap: _selectDeadline,
//           child: Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: AppColors.edgeBackground,
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Row(
//               children: [
//                 const Icon(
//                   Icons.calendar_today,
//                   size: 18,
//                   color: AppColors.edgePrimary,
//                 ),
//                 const SizedBox(width: 8),
//                 Text(
//                   _selectedDeadline != null
//                       ? DateFormat('MMM d, y').format(_selectedDeadline!)
//                       : 'Select deadline',
//                   style: TextStyle(
//                     fontSize: 15,
//                     color: _selectedDeadline != null
//                         ? AppColors.edgeText
//                         : AppColors.edgeTextSecondary,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildInlineDaysTakenField() {
//     final daysTakenController = TextEditingController(
//       text: _timeTaken != null ? '$_timeTaken' : '',
//     );

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Row(
//           children: [
//             Icon(Icons.timer_outlined, color: AppColors.edgePrimary, size: 18),
//             SizedBox(width: 8),
//             Text(
//               'Days Taken',
//               style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.edgeText,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             IconButton(
//               onPressed: () {
//                 if (_timeTaken != null && _timeTaken! > 0) {
//                   setState(() {
//                     _timeTaken = _timeTaken! - 1;
//                   });
//                 }
//               },
//               icon: const Icon(Icons.remove_circle_outline),
//               color: AppColors.edgePrimary,
//             ),
//             Expanded(
//               child: TextFormField(
//                 controller: daysTakenController,
//                 keyboardType: TextInputType.number,
//                 textAlign: TextAlign.left,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   color: AppColors.edgeText,
//                   fontWeight: FontWeight.w600,
//                 ),
//                 decoration: InputDecoration(
//                   hintText: 'Enter days',
//                   suffixText: 'days',
//                   filled: true,
//                   fillColor: AppColors.edgeBackground,
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                     borderSide: BorderSide.none,
//                   ),
//                   contentPadding: const EdgeInsets.symmetric(
//                     horizontal: 12,
//                     vertical: 12,
//                   ),
//                 ),
//                 onChanged: (value) {
//                   if (value.isEmpty) {
//                     setState(() {
//                       _timeTaken = null;
//                     });
//                   } else {
//                     final parsed = int.tryParse(value);
//                     if (parsed != null && parsed >= 0) {
//                       setState(() {
//                         _timeTaken = parsed;
//                       });
//                     }
//                   }
//                 },
//               ),
//             ),
//             IconButton(
//               onPressed: () {
//                 setState(() {
//                   _timeTaken = (_timeTaken ?? 0) + 1;
//                 });
//               },
//               icon: const Icon(Icons.add_circle_outline),
//               color: AppColors.edgePrimary,
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildInlineToggleField({
//     required String label,
//     required bool value,
//     required ValueChanged<bool> onChanged,
//     required bool isRequired,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             const Icon(
//               Icons.check_circle_outline,
//               color: AppColors.edgePrimary,
//               size: 18,
//             ),
//             const SizedBox(width: 8),
//             Text(
//               label,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.edgeText,
//               ),
//             ),
//             if (isRequired)
//               const Text(
//                 ' *',
//                 style: TextStyle(color: AppColors.edgeError, fontSize: 14),
//               ),
//             const Spacer(),
//             Switch(
//               value: value,
//               onChanged: onChanged,
//               activeThumbColor: AppColors.edgePrimary,
//               activeTrackColor: AppColors.edgePrimary.withOpacity(0.5),
//               inactiveThumbColor: Colors.grey.shade400,
//               inactiveTrackColor: Colors.grey.shade300,
//             ),
//           ],
//         ),
//       ],
//     );
//   }
// }
