import 'package:cardabase/data/unique_id.dart';
import 'package:cardabase/feature/cards/edit/widgets/edit_card_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';

class AddCardButton extends StatelessWidget {
  const AddCardButton({
    super.key,
  });

  Future<void> addCard(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (builder) => EditCardPage(
          cardId: generateUniqueId(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Bounceable(
      onTap: () {},
      child: SizedBox(
        height: 70,
        width: 70,
        child: FittedBox(
          child: FloatingActionButton(
            elevation: 0.0,
            enableFeedback: true,
            tooltip: 'Add a card',
            onPressed: () => addCard(context),
            child: const Icon(Icons.add_card),
          ),
        ),
      ),
    );
  }
}
