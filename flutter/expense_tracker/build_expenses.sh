#!/bin/bash
flutter build web --output build/expenses-web
firebase deploy --only hosting:expenses
