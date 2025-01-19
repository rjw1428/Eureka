import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/models/pending_request.dart';
import 'package:expense_tracker/services/account_link.service.dart';
import 'package:expense_tracker/services/auth.service.dart';
import 'package:expense_tracker/services/categories.service.dart';
import 'package:expense_tracker/services/theme_color.service.dart';
import 'package:expense_tracker/widgets/category_form.dart';
import 'package:expense_tracker/widgets/show_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _SettingsScreenState();
  }
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool showLinkForm = false;
  final _emailField = TextEditingController();

  void _openAddCategoryOverlay([CategoryDataWithId? category]) {
    showModalBottomSheet(
      useSafeArea: true,
      isScrollControlled: true,
      context: context,
      builder: (ctx) {
        return CategoryForm(
          onSubmit: category == null ? _addCategory : _updateCategory,
          initialCategory: category,
          onRemove: _removeCategory,
        );
      },
    );
  }

  void _addCategory(CategoryDataWithId category) {
    CategoriesService().addCategory(category);
  }

  void _updateCategory(CategoryDataWithId category) {
    CategoriesService().updateCategory(category);
  }

  void _removeCategory(CategoryDataWithId category) {
    CategoriesService().remove(category);
  }

  void _showColorSelector(BuildContext context) {
    Color selectedColor = ThemeColorService().currentColor;
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
          final result =
              "${selectedColor.alpha},${selectedColor.red},${selectedColor.green},${selectedColor.blue}";
          SharedPreferences preferences = await SharedPreferences.getInstance();
          await preferences.setString('theme_color', result);
          ThemeColorService().selectColor(selectedColor);
          Navigator.pop(context);
        },
        child: const Text('Save'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;

    return StreamBuilder(
        stream: AuthService().getAccount().switchMap(
              (account) => CombineLatestStream.combine2(
                CategoriesService().getCategoriesStream(account.ledgerId, withDeleted: false),
                AccountLinkService().pendingLinkRequestList(account.id),
                (categoryList, pendingRequestList) => {
                  'categoryList': categoryList,
                  'pendingRequestList': pendingRequestList,
                  'user': account,
                },
              ),
            ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(snapshot.error.toString());
          }

          final List<CategoryDataWithId> configs =
              !snapshot.hasData ? [] : snapshot.data!['categoryList']! as List<CategoryDataWithId>;
          final List<PendingRequest> requestList = !snapshot.hasData
              ? []
              : snapshot.data!['pendingRequestList']! as List<PendingRequest>;
          final ExpenseUser? user =
              !snapshot.hasData ? null : snapshot.data!['user']! as ExpenseUser;

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
                      Text(
                        'Spending Categories:',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.start,
                      ),
                      CategoryList(
                        categoryList: configs,
                        editable: user?.role == 'primary',
                        onEdit: _openAddCategoryOverlay,
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: OutlinedButton.icon(
                            onPressed: _openAddCategoryOverlay,
                            label: const Text('Add a spending category'),
                            icon: const Icon(Icons.playlist_add),
                          ),
                        ),
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
                      if ((user?.linkedAccounts ?? []).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Center(
                              child: Text(
                            'Linked Accounts',
                            style: Theme.of(context).textTheme.titleMedium,
                          )),
                        ),
                      Column(
                        children: (user?.linkedAccounts ?? []).map((link) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(link['email']!),
                                  ),
                                  // Row(
                                  //   children: [
                                  //     TextButton(
                                  //         onPressed: () => onRemove(request),
                                  //         child: const Icon(Icons.delete_outline)),
                                  //   ],
                                  // )
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      RequestList(
                          requestList: requestList, onRemove: AccountLinkService().removeRequest),
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

                                final response = await AccountLinkService().sendLinkRequest(
                                  _emailField.text,
                                  AuthService().user!.uid,
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
                        'Color Theme',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.start,
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: OutlinedButton.icon(
                            onPressed: () => _showColorSelector(context),
                            label: const Text('Select color'),
                            icon: const Icon(Icons.color_lens_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }
}

class CategoryList extends StatelessWidget {
  const CategoryList({
    super.key,
    required this.categoryList,
    required this.onEdit,
    required this.editable,
  });

  final List<CategoryDataWithId> categoryList;
  final void Function(CategoryDataWithId) onEdit;
  final bool editable;

  @override
  Widget build(Object context) {
    return Column(
        children: categoryList
            .map((category) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Icon(category.iconData),
                              ),
                              Text(category.label),
                            ],
                          ),
                        ),
                        Text(
                          'Budget Amount: \$${category.budget.toStringAsFixed(2)}',
                          textAlign: TextAlign.end,
                        ),
                        if (editable)
                          Row(
                            children: [
                              TextButton(
                                  onPressed: () => onEdit(category), child: const Icon(Icons.edit)),
                            ],
                          )
                      ],
                    ),
                  ),
                ))
            .toList());
  }
}

class RequestList extends StatelessWidget {
  const RequestList({super.key, required this.requestList, required this.onRemove});

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
