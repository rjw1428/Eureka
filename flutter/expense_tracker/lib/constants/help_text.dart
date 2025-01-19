class HelpTextItem {
  final String title;
  final String info;

  const HelpTextItem({required this.title, required this.info});
}

const helpText = [
  HelpTextItem(
    title: 'Why should I do this?',
    info:
        '''The benefits of manually adding an expense is that it provides some friction to making a transaction, similar to spending cash.''',
  ),
  HelpTextItem(
    title: 'What makes this different?',
    info:
        '''You can share your ledger with people so that they can also add to the ledger. Think about you and your significant other trying to maintain a household budget.''',
  ),
  HelpTextItem(
    title: 'Create a budget',
    info:
        '''Open the settings menu and add a category. From there you will be able to provide the amount you are trying to stick to. As you approach that amount in your spend for the selected month, a line will appear on the chart to indicate where your budget is relative to your spend.''',
  ),
];
