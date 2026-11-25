import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/domain/andamento.dart';
import 'package:personal_finance/domain/mese.dart';
import 'package:personal_finance/domain/voce.dart';
import 'package:personal_finance/ui/andamento/composizione_torte.dart';
import 'package:personal_finance/ui/andamento/grafico_area.dart';
import 'package:personal_finance/ui/andamento/grafico_linee.dart';
import 'package:personal_finance/ui/andamento/riquadri_variazioni.dart';
import 'package:personal_finance/ui/app_theme.dart';
import 'package:personal_finance/ui/etichette.dart';

List<PuntoMensile> serie(Mese inizio, int n) => [
  for (var i = 0; i < n; i++)
    PuntoMensile(
      mese: Mese(
        inizio.anno + (inizio.mese - 1 + i) ~/ 12,
        (inizio.mese - 1 + i) % 12 + 1,
      ),
      totale: 1000000 + i * 100000,
      liquiditaConSalvadanaio: 500000,
      investimenti: 500000 + i * 100000,
      categorie: {
        CategoriaInvestimento.pianiAccumulo: 100000 + i * 100000,
        CategoriaInvestimento.p2pLanding: 200000,
        CategoriaInvestimento.depositoTitoli: 0,
        CategoriaInvestimento.crypto: 200000,
      },
    ),
];

Future<void> mostra(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Scaffold(body: SingleChildScrollView(child: w)),
    ),
  );
}

LineTouchResponse rispostaLinee(LineChartData d, int indice) {
  final bar = d.lineBarsData.first;
  return LineTouchResponse(
    touchLocation: Offset.zero,
    touchChartCoordinate: Offset.zero,
    lineBarSpots: [TouchLineBarSpot(bar, 0, bar.spots[indice], 0)],
  );
}

FlPointerHoverEvent hover() => const FlPointerHoverEvent(PointerHoverEvent());

void main() {
  testWidgets('linee: il passaggio del mouse mostra il valore', (t) async {
    await mostra(t, GraficoLinee(serie: serie(Mese(2026, 1), 6)));
    final d = t.widget<LineChart>(find.byType(LineChart)).data;
    d.lineTouchData.touchCallback!(hover(), rispostaLinee(d, 2));
    await t.pump();
    expect(find.text('Marzo 2026'), findsOneWidget);
    expect(find.textContaining('€ 12.000,00'), findsOneWidget);
  });

  testWidgets('linee: la selezione si azzera se cambia il primo mese', (
    t,
  ) async {
    await mostra(t, GraficoLinee(serie: serie(Mese(2026, 1), 6)));
    var d = t.widget<LineChart>(find.byType(LineChart)).data;
    d.lineTouchData.touchCallback!(hover(), rispostaLinee(d, 2));
    await t.pump();
    expect(find.text('Marzo 2026'), findsOneWidget);
    await mostra(t, GraficoLinee(serie: serie(Mese(2026, 2), 6)));
    expect(find.textContaining('2026'), findsNothing);
  });

  testWidgets('area: valore al tocco e legenda che nasconde le categorie', (
    t,
  ) async {
    await mostra(t, GraficoArea(serie: serie(Mese(2026, 1), 6)));
    var d = t.widget<LineChart>(find.byType(LineChart)).data;
    expect(d.lineBarsData, hasLength(4));
    d.lineTouchData.touchCallback!(hover(), rispostaLinee(d, 1));
    await t.pump();
    expect(find.text('Febbraio 2026'), findsOneWidget);
    expect(find.textContaining('Piani accumulo: € 2.000,00'), findsOneWidget);
    expect(find.textContaining('Crypto: € 2.000,00'), findsOneWidget);

    await t.tap(find.widgetWithText(FilterChip, 'Crypto'));
    await t.pump();
    d = t.widget<LineChart>(find.byType(LineChart)).data;
    expect(d.lineBarsData, hasLength(3));
    expect(find.textContaining('Crypto: €'), findsNothing);
  });

  testWidgets('torte: valore al tocco', (t) async {
    final quota = (importo: 300000, percentuale: 3000);
    await mostra(
      t,
      ComposizioneTorte(
        composizione: Composizione(
          gruppi: {
            Gruppo.salvadanaio: (importo: 0, percentuale: 0),
            Gruppo.liquidita: quota,
            Gruppo.investimenti: (importo: 700000, percentuale: 7000),
          },
        ),
      ),
    );
    final d = t.widget<PieChart>(find.byType(PieChart)).data;
    d.pieTouchData.touchCallback!(
      hover(),
      PieTouchResponse(
        touchLocation: Offset.zero,
        touchedSection: PieTouchedSection(d.sections[1], 1, 0, 0),
      ),
    );
    await t.pump();
    expect(find.text('Importo: € 3.000,00  30,00%'), findsOneWidget);
  });

  testWidgets('variazioni: segno e colore dalla singola cifra', (t) async {
    await mostra(
      t,
      RiquadriVariazioni(
        variazioni: VariazioniTotale(
          precedente: Variazione(
            confronto: Mese(2026, 1),
            differenza: 50000,
            percentuale: -5000,
          ),
          gennaio: Variazione(confronto: Mese(2026, 1)),
          annoPrecedente: Variazione(confronto: Mese(2025, 2)),
        ),
      ),
    );
    expect(find.text('+€ 500,00 · -50,00%'), findsOneWidget);
    final span =
        t
                .widget<RichText>(
                  find
                      .descendant(
                        of: find.byKey(const ValueKey('variazione-precedente')),
                        matching: find.byType(RichText),
                      )
                      .last,
                )
                .text
            as TextSpan;
    final colori = <Color>[];
    span.visitChildren((c) {
      if (c is TextSpan && c.style?.color != null) colori.add(c.style!.color!);
      return true;
    });
    expect(colori.first, colorePositivo);
    expect(colori.last, coloreNegativo);
  });

  test('importi compatti degli assi', () {
    expect(scriviCompatto(120000), '€ 120k');
    expect(scriviCompatto(1500), '€ 1,5k');
    expect(scriviCompatto(2500000), '€ 2,5M');
    expect(scriviCompatto(800), '€ 800');
    expect(scriviCompatto(0), '€ 0');
  });
}
