import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

final randomizer = Random();

class Dice extends StatefulWidget {
  const Dice({super.key});

  @override
  State<Dice> createState() {
    return _DiceState();
  }
}

class _DiceState extends State<Dice> {
  int dice1 = 2;
  int dice2 = 3;
  int? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 64.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/dice-$dice1.png', width: 200),
                  Image.asset('assets/images/dice-$dice2.png', width: 200)
                ],
              ),
              if (value != null)
                Text(
                  'You rolled a $value',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      shadows: [Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 2)]),
                ),
            ],
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white),
          onPressed: rollDice,
          child: const Text(
            'Roll Dice',
            style: TextStyle(fontSize: 24),
          ),
        )
      ],
    );
  }

  void rollDice() {
    setState(() {
      dice1 = randomizer.nextInt(6) + 1;
      dice2 = randomizer.nextInt(6) + 1;
      value = dice1 + dice2;
    });
  }
}
