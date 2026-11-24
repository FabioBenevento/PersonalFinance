import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/domain/voce.dart';
import 'package:personal_finance/domain/voci_iniziali.dart';

void main() {
  test('CAT-001 quattro categorie con mappatura iniziale completa', () {
    expect(CategoriaInvestimento.values, [
      CategoriaInvestimento.pianiAccumulo,
      CategoriaInvestimento.p2pLanding,
      CategoriaInvestimento.depositoTitoli,
      CategoriaInvestimento.crypto,
    ]);
    expect(
      {
        for (final v in vociIniziali.where(
          (v) => v.gruppo == Gruppo.investimenti,
        ))
          v.nome: v.categoria,
      },
      {
        'P2PLanding': CategoriaInvestimento.p2pLanding,
        'Deposito Titoli – Scalable Capital':
            CategoriaInvestimento.depositoTitoli,
        'Deposito Titoli – TradeRepublic': CategoriaInvestimento.depositoTitoli,
        'Deposito Titoli – Directa': CategoriaInvestimento.depositoTitoli,
        'Deposito Titoli – DeGiro': CategoriaInvestimento.depositoTitoli,
        'Interactive Brokers': CategoriaInvestimento.depositoTitoli,
        'Pensionline': CategoriaInvestimento.pianiAccumulo,
        'Piano Piano': CategoriaInvestimento.pianiAccumulo,
        'Crypto': CategoriaInvestimento.crypto,
        'Crowdfounding': CategoriaInvestimento.p2pLanding,
      },
    );
    expect(
      vociIniziali
          .where((v) => v.gruppo != Gruppo.investimenti)
          .map((v) => v.categoria),
      everyElement(isNull),
    );
  });

  test('SIT-022 voci iniziali: conteggi, ordine, saldi e nomi univoci', () {
    Iterable<String> nomi(Gruppo g) =>
        vociIniziali.where((v) => v.gruppo == g).map((v) => v.nome);
    Voce voce(String n) => vociIniziali.firstWhere((v) => v.nome == n);

    expect(vociIniziali, hasLength(24));
    expect(nomi(Gruppo.salvadanaio), [
      'Contanti',
      'PayPal',
      'Satispay',
      'MatchBetting',
    ]);
    expect(nomi(Gruppo.liquidita), hasLength(10));
    expect(nomi(Gruppo.liquidita).first, 'Youbanking');
    expect(nomi(Gruppo.liquidita).last, 'Mediolanum');
    expect(nomi(Gruppo.investimenti), hasLength(10));
    expect(nomi(Gruppo.investimenti).first, 'P2PLanding');
    expect(nomi(Gruppo.investimenti).last, 'Crowdfounding');

    expect(voce('MatchBetting').righe, hasLength(18));
    expect(voce('P2PLanding').righe, hasLength(4));
    expect(voce('Crypto').righe, hasLength(4));
    expect(vociIniziali.where((v) => v.conDettaglio), hasLength(3));

    expect(vociIniziali.every((v) => v.saldoCentesimi == 0), isTrue);
    final n = vociIniziali.map((v) => v.nome.toLowerCase()).toSet();
    expect(n, hasLength(24));
    final ids = vociIniziali.map((v) => v.id).toSet();
    expect(ids, hasLength(24));
  });
}
