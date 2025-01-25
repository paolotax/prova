class FatturaElettronicaXml
  include ActiveModel::Model
  
  def initialize(documento)
    @documento = documento
  end

  def genera_xml
    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.FatturaElettronica(versione: 'FPR12', 
                            xmlns: "http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2") {
        
        xml.FatturaElettronicaHeader {
          genera_dati_trasmissione(xml)
          genera_cedente_prestatore(xml)
          genera_cessionario_committente(xml)
        }
        
        xml.FatturaElettronicaBody {
          #genera_dati_generali(xml)
          #genera_dati_beni_servizi(xml)
          #genera_dati_pagamento(xml) if @documento.tipo_pagamento.present?
        }
      }
    end
    
    builder.to_xml
  end

  private

  def genera_dati_trasmissione(xml)
    xml.DatiTrasmissione {
      xml.IdTrasmittente {
        xml.IdPaese 'IT'
        xml.IdCodice @documento.user&.azienda_partita_iva
      }
      xml.ProgressivoInvio @documento.numero_documento
      xml.FormatoTrasmissione 'FPR12'
      xml.CodiceDestinatario @documento.clientable.indirizzo_telematico
    }
  end

  def genera_cedente_prestatore(xml)
    xml.CedentePrestatore {
      xml.DatiAnagrafici {
        xml.IdFiscaleIVA {
          xml.IdPaese 'IT'
          xml.IdCodice @documento.user&.azienda_partita_iva
        }
        xml.CodiceFiscale @documento.user&.azienda_codice_fiscale
        xml.Anagrafica {
          xml.Denominazione @documento.user&.azienda_ragione_sociale
        }
        xml.RegimeFiscale 'RF07'  # Regime forfettario
      }
      xml.Sede {
        xml.Indirizzo @documento.user&.azienda_indirizzo
        xml.CAP @documento.user&.azienda_cap
        xml.Comune @documento.user&.azienda_comune
        xml.Provincia @documento.user&.azienda_provincia
        xml.Nazione 'IT'
      }
      xml.Contatti {
        xml.Email @documento.user&.azienda_email
      }
    }
  end

  def genera_cessionario_committente(xml)
    xml.CessionarioCommittente {
      xml.DatiAnagrafici {
        xml.IdFiscaleIVA {
          xml.IdPaese 'IT'
          xml.IdCodice @documento.clientable.partita_iva
        }
        xml.CodiceFiscale @documento.clientable.codice_fiscale if @documento.clientable.codice_fiscale.present?
        xml.Anagrafica {
          xml.Denominazione @documento.clientable.denominazione
        }
      }
      xml.Sede {
        xml.Indirizzo @documento.clientable.indirizzo
        xml.CAP @documento.clientable.cap
        xml.Comune @documento.clientable.comune
        xml.Provincia @documento.clientable.provincia
        xml.Nazione 'IT'
      }
    }
  end

  def genera_dati_generali(xml)
    xml.DatiGenerali {
      xml.DatiGeneraliDocumento {
        xml.TipoDocumento 'TD01'
        xml.Divisa 'EUR'
        xml.Data @documento.data_documento.strftime('%Y-%m-%d')
        xml.Numero "FPR #{@documento.numero_documento}/#{@documento.data_documento.strftime('%y')}"
        xml.ImportoTotaleDocumento format('%.2f', @documento.totale_importo)
      }
      genera_dati_ddt(xml) if @documento.ddt.present?
    }
  end

  def genera_dati_beni_servizi(xml)
    xml.DatiBeniServizi {
      @documento.righe.each_with_index do |riga, index|
        xml.DettaglioLinee {
          xml.NumeroLinea index + 1
          xml.CodiceArticolo {
            xml.CodiceTipo 'ISBN'
            xml.CodiceValore riga.libro.codice
          }
          xml.Descrizione riga.libro.titolo
          xml.Quantita format('%.2f', riga.quantita)
          xml.UnitaMisura 'CP'
          xml.PrezzoUnitario format('%.2f', riga.prezzo)
          xml.ScontoMaggiorazione {
            xml.Tipo 'SC'
            xml.Percentuale '20.00'
          }
          xml.PrezzoTotale format('%.2f', riga.importo)
          xml.AliquotaIVA '0.00'
          xml.Natura 'N2.2'
        }
      end
      
      xml.DatiRiepilogo {
        xml.AliquotaIVA '0.00'
        xml.Natura 'N2.2'
        xml.ImponibileImporto format('%.2f', @documento.totale_importo)
        xml.Imposta '0.00'
        xml.RiferimentoNormativo 'Non soggette - altri casi'
      }
    }
  end

  def genera_dati_pagamento(xml)
    xml.DatiPagamento {
      xml.CondizioniPagamento 'TP02'
      xml.DettaglioPagamento {
        xml.ModalitaPagamento 'MP05'
        xml.DataScadenzaPagamento @documento.data_documento.strftime('%Y-%m-%d')
        xml.ImportoPagamento format('%.2f', @documento.totale_importo)
        xml.IstitutoFinanziario @documento.user&.azienda_banca
        xml.IBAN @documento.user&.azienda_iban
      }
    }
  end

  def genera_dati_ddt(xml)
    @documento.ddt.each do |ddt|
      xml.DatiDDT {
        xml.NumeroDDT "DDT #{ddt.numero}/#{ddt.anno}"
        xml.DataDDT ddt.data.strftime('%Y-%m-%d')
        ddt.righe.each do |riga|
          xml.RiferimentoNumeroLinea riga.numero_linea
        end
      }
    end
  end
end