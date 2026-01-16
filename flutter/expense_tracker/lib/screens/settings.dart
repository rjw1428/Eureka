import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/models/linked_user.dart';
import 'package:expense_tracker/models/pending_request.dart';
import 'package:expense_tracker/models/settings.dart';
import 'package:expense_tracker/providers/settings_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/account_link.service.dart';
import 'package:expense_tracker/widgets/show_dialog.dart';
import 'package:expense_tracker/widgets/user_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() {
    return _SettingsScreenState();
  }
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool showLinkForm = false;
  final _emailField = TextEditingController();
  final _firstNameField = TextEditingController();
  final _lastNameField = TextEditingController();

  void _showColorSelector(BuildContext context, ExpenseUser user) {
    Color selectedColor =
        ref.read(settingsProvider.select((settings) => settings.color));
    showDialogNotification(
      'Select a color',
      HueRingPicker(
        pickerColor: selectedColor,
        onColorChanged: (c) => selectedColor = c,
        enableAlpha: false,
        displayThumbColor: true,
      ),
      context,
      TextButton(
        onPressed: () async {
          ref.read(settingsProvider.notifier).setColor(selectedColor);
          Navigator.pop(context);
        },
        child: const Text('Save'),
      ),
    );
  }

  void _openUnlinkConfirmationDialog(
      LinkedUser linkedAccount, ExpenseUser user) {
    showDialogNotification(
      'Are you sure you want to unlink?',
      Text(
        user.role == 'primary'
            ? 'If you remove this account, they will no longer be able to see any expenses from you or any expenses that were added to your ledger. The ones that they have already added will remain.'
            : 'If you remove your account link, you will no longer be able to see any expenses from them or any expenses that were added to by you. You will be reverted back to the your ledger before your account was linked',
      ),
      context,
      TextButton(
        onPressed: () {
          AccountLinkService().onUnlink(linkedAccount, user);
          Navigator.pop(context);
        },
        child: const Text('Confirm'),
      ),
    );
  }

  void onDeleteAccount(ExpenseUser user) {
    showDialogNotification(
      'Are you sure you want delete your accounut?',
      Text(
        user.linkedAccounts.isNotEmpty
            ? 'Deleting your account will also unlink all of your linked accounts. Any expenses that were added to by you will remain for the linked user. This action cannot be undone.'
            : 'Deleting your accounut will remove all of your data from the app. This action cannot be undone.',
      ),
      context,
      TextButton(
        onPressed: () async {
          final result = await AccountLinkService().onDeleteAccount(user);
          ref.read(userCreationStateProvider.notifier).loggedOut();
          if (mounted) {
            if (result != 'success') {
              Navigator.pop(context);
              showDialogNotification(
                'Error Deleting Account',
                Text(result),
                context,
              );
              return;
            }
            Navigator.pushNamedAndRemoveUntil(
                context, '/', (Route<dynamic> route) => false);
          }
        },
        child: const Text('I am sure'),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameField.dispose();
    _lastNameField.dispose();
    _emailField.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ref.read(settingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
    final userSettings = ref.watch(settingsProvider);
    final user = ref.watch(userProvider).valueOrNull;

    if (user == null) {
      return const Text("Oh Shit");
    }

    final List<PendingRequest> requestList = [];
    _firstNameField.text = user.firstName;
    _lastNameField.text = user.lastName;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, keyboardSpace + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Center(
                    child: UserIcon(
                  user: LinkedUser.fromUser(user),
                  size: 80,
                )),
                const SizedBox(height: 16),
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(children: [
                  const Text('First Name:'),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(user.firstName),
                  ),
                ]),
                Row(children: [
                  const Text('Last Name:'),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(user.lastName),
                  ),
                ]),
                Row(
                  children: [
                    const Text('Email Address:'),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(user.email),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Link your spending',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.start,
                ),
                Text(
                  'Send a request to another user. When they accept, all transactions will appear on each others accounts.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.start,
                ),
                if (user.linkedAccounts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Center(
                        child: Text(
                      'Linked Accounts',
                      style: Theme.of(context).textTheme.titleMedium,
                    )),
                  ),
                Column(
                  children: user.linkedAccounts.map((link) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(link.email),
                            ),
                            TextButton(
                                onPressed: () =>
                                    _openUnlinkConfirmationDialog(link, user),
                                child: const Icon(Icons.link_off_outlined)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                RequestList(
                    requestList: requestList,
                    onRemove: AccountLinkService().removeRequest),
                if (!showLinkForm)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => showLinkForm = true),
                        label: const Text('Link with user'),
                        icon: const Icon(Icons.library_add),
                      ),
                    ),
                  ),
                if (showLinkForm)
                  Material(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _emailField,
                        decoration: const InputDecoration(
                          label: Text('Email Address'),
                        ),
                      ),
                    ),
                  ),
                if (showLinkForm)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (_emailField.text.trim().isEmpty) {
                            showDialogNotification(
                              'Invalid Email',
                              const Text('Please enter an email address'),
                              context,
                            );
                            return;
                          }

                          final RegExp emailRegex = RegExp(
                              r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                          if (!emailRegex.hasMatch(_emailField.text.trim())) {
                            showDialogNotification(
                              'Invalid Email',
                              const Text('Please enter a valid email address'),
                              context,
                            );
                            return;
                          }

                          if (requestList
                              .map((req) => req.targetEmail)
                              .contains(_emailField.text.trim())) {
                            showDialogNotification(
                              'Already Requested',
                              const Text(
                                  'The email address provided has already been requested'),
                              context,
                            );
                            return;
                          }
                          final response =
                              await AccountLinkService().sendLinkRequest(
                            _emailField.text,
                            user.id,
                          );
                          if (!response.success) {
                            showDialogNotification(
                              'Invite Failed',
                              Text(response.message!),
                              context,
                            );
                            return;
                          }

                          showDialogNotification(
                            'Invite Success!',
                            const Text(
                                '''An invite has been sent to the provided email address. If they have an account, they will be notified shortly. If they do not already have an account, an email will be sent to them inviting them to join.'''),
                            context,
                          );
                          setState(() {
                            showLinkForm = false;
                            _emailField.text = '';
                          });
                        },
                        label: const Text('Send Request'),
                        icon: const Icon(Icons.send_outlined),
                      ),
                    ),
                  ),
                if (showLinkForm)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() {
                          showLinkForm = false;
                          _emailField.text = '';
                        }),
                        label: const Text('Cancel'),
                        icon: const Icon(Icons.undo),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Notification Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.start,
                ),
                SwitchListTile(
                  title: const Text('Overspending Individual Category'),
                  value: userSettings
                      .notificationSettings.overspendingIndividualBudget,
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .toggleOverspendingIndividualBudget(value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Overspending Total Budget'),
                  value:
                      userSettings.notificationSettings.overspendingTotalBudget,
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .toggleOverspendingTotalBudget(value);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Theme',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.start,
                ),
                Center(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'light',
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: 'dark',
                        label: Text('Dark'),
                      ),
                      ButtonSegment(
                        value: 'auto',
                        label: Text('Auto'),
                      ),
                    ],
                    selected: {userSettings.theme},
                    onSelectionChanged: (value) {
                      ref.read(settingsProvider.notifier).setTheme(value.first);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Color Theme',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.start,
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: OutlinedButton.icon(
                      onPressed: () => _showColorSelector(context, user),
                      label: const Text('Select color'),
                      icon: const Icon(Icons.color_lens_outlined),
                    ),
                  ),
                ),
                Divider(
                    height: 48,
                    thickness: 2,
                    indent: 5,
                    endIndent: 5,
                    color: Theme.of(context).colorScheme.secondary),
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                    ),
                    onPressed: () => onDeleteAccount(user),
                    label: const Text("Delete Account",
                        textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RequestList extends StatelessWidget {
  const RequestList(
      {super.key, required this.requestList, required this.onRemove});

  final List<PendingRequest> requestList;
  final void Function(PendingRequest) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (requestList.isNotEmpty)
          Text(
            'Pending Requests',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ...requestList.map((request) => Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(request.targetEmail),
                    ),
                    Row(
                      children: [
                        TextButton(
                            onPressed: () => onRemove(request),
                            child: const Icon(Icons.delete_outline)),
                      ],
                    )
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
