class FatturaElettronicaXml
  include ActiveModel::Model
  
  def initialize(documento)
    @documento = documento
  end

  def genera_xml
    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.p('versione' => '1.2.1', 
            'xmlns:ds' => "http://www.w3.org/2000/09/xmldsig#",
            'xmlns:p' => "http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2",
            'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance") {
        
        xml.FatturaElettronicaHeader {
          genera_dati_trasmissione(xml)
          genera_cedente_prestatore(xml)
          genera_cessionario_committente(xml)
        }
        
        xml.FatturaElettronicaBody {
          genera_dati_generali(xml)
          genera_dati_beni_servizi(xml)
          genera_dati_pagamento(xml) if @documento.pagamento.present?
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
        xml.IdCodice @documento.azienda.codice_fiscale
      }
      xml.ProgressivoInvio @documento.numero
      xml.FormatoTrasmissione 'FPR12'
      xml.CodiceDestinatario @documento.cliente.codice_destinatario
    }
  end

  def genera_cedente_prestatore(xml)
    xml.CedentePrestatore {
      xml.DatiAnagrafici {
        xml.IdFiscaleIVA {
          xml.IdPaese 'IT'
          xml.IdCodice @documento.azienda.partita_iva
        }
        xml.Anagrafica {
          xml.Denominazione @documento.azienda.ragione_sociale
        }
        xml.RegimeFiscale 'RF01' # Modificare in base al regime fiscale
      }
      # Aggiungere sede e contatti
    }
  end

  def genera_cessionario_committente(xml)
    xml.CessionarioCommittente {
      xml.DatiAnagrafici {
        xml.IdFiscaleIVA {
          xml.IdPaese 'IT'
          xml.IdCodice @documento.cliente.partita_iva
        }
        xml.Anagrafica {
          xml.Denominazione @documento.cliente.ragione_sociale
        }
      }
      # Aggiungere sede
    }
  end

  def genera_dati_generali(xml)
    xml.DatiGenerali {
      xml.DatiGeneraliDocumento {
        xml.TipoDocumento 'TD01'
        xml.Divisa 'EUR'
        xml.Data @documento.data.strftime('%Y-%m-%d')
        xml.Numero @documento.numero
        xml.ImportoTotaleDocumento format('%.2f', @documento.totale)
      }
    }
  end

  def genera_dati_beni_servizi(xml)
    xml.DatiBeniServizi {
      @documento.righe.each_with_index do |riga, index|
        xml.DettaglioLinee {
          xml.NumeroLinea index + 1
          xml.Descrizione riga.descrizione
          xml.Quantita format('%.2f', riga.quantita)
          xml.PrezzoUnitario format('%.2f', riga.prezzo_unitario)
          xml.PrezzoTotale format('%.2f', riga.prezzo_totale)
          xml.AliquotaIVA format('%.2f', riga.aliquota_iva)
        }
      end
      
      # Riepilogo IVA
      @documento.riepilogo_iva.each do |iva|
        xml.DatiRiepilogo {
          xml.AliquotaIVA format('%.2f', iva.aliquota)
          xml.ImponibileImporto format('%.2f', iva.imponibile)
          xml.Imposta format('%.2f', iva.imposta)
        }
      end
    }
  end

  def genera_dati_pagamento(xml)
    xml.DatiPagamento {
      xml.CondizioniPagamento 'TP02'
      xml.DettaglioPagamento {
        xml.ModalitaPagamento 'MP05' # Bonifico
        xml.DataScadenzaPagamento @documento.data_scadenza.strftime('%Y-%m-%d')
        xml.ImportoPagamento format('%.2f', @documento.totale)
      }
    }
  end
end 