import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/screens/create_account/create_profile_step.dart';
import 'package:expense_tracker/screens/create_account/init_budget_step.dart';
import 'package:expense_tracker/services/account_link.service.dart';
import 'package:expense_tracker/services/auth.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({
    super.key,
    this.appleProfile,
  });

  final AppleUserProfile? appleProfile;

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _pageController = PageController();
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final String email = AuthService().currentUser?.email ?? '';
  final List<CategoryDataWithId> _categories = [];

  @override
  void initState() {
    if (widget.appleProfile != null) {
      _firstNameController.text = widget.appleProfile!.givenName;
      _lastNameController.text = widget.appleProfile!.familyName;
    }
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<String> createUserBudget(
      String userId, List<CategoryDataWithId> categories) async {
    final budgetMap = {
      for (var category in categories) category.id: category.toJson(),
    };
    debugPrint(budgetMap.toString());
    try {
      final doc = await ref.read(backendProvider).collection('ledger').add({
        'budgetConfig': budgetMap,
      });
      return doc.id;
    } catch (e) {
      debugPrint('Error creating user budget: $e');
      return '';
    }
  }

  Future<void> _saveUserProfile(
      String userId, List<CategoryDataWithId> categories) async {
    final isValid = _formKey2.currentState?.validate() ?? false;
    if (isValid) {
      try {
        final ledgerId = await createUserBudget(userId, categories);
        debugPrint('Created ledger with ID: $ledgerId');
        if (ledgerId.isEmpty) {
          throw Exception('Failed to create ledger');
        }
        final userProfile = ExpenseUser(
          id: userId,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          email: email,
          ledgerId: ledgerId,
          role: 'primary',
          initialized: DateTime.now(),
          userSettings: {'color': kDefaultColorString},
          linkedAccounts: [],
          archivedLinkedAccounts: [],
          noteSuggestions: {},
        );
        await AuthService().createUserProfile(userProfile);
        ref.read(userCreationStateProvider.notifier).setCreated();
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(userIdProvider).value;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to $APP_TITLE!'),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          if (widget.appleProfile == null)
            CreateProfileStep(
              formKey: _formKey1,
              firstNameController: _firstNameController,
              lastNameController: _lastNameController,
              onCreate: () => {
                if (_formKey1.currentState!.validate())
                  {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                  }
              },
            ),
          CreateInitialBudgetStep(
            formKey: _formKey2,
            categories: _categories,
            firstName: _firstNameController.text,
            onCreate: (categories) async {
              await _saveUserProfile(userId, categories);
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            onBack: () async {
              if (widget.appleProfile != null) {
                final resp = await AccountLinkService().deleteFirebaseAccount(ref);
                debugPrint('Account deletion response: $resp');
                ref.read(userCreationStateProvider.notifier).loggedOut();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/', (route) => false);
              }
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          )
        ],
      ),
    );
  }
}
