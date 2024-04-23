module AdozioniHelper

    def quante_maestre(team)
		
        if team.split(",").size == 1 && team.split(" e ").size == 1
			return 1
		else
			team.split(",").map{ |m| m.split(" e ") }.flatten.size
		end
    end

    def maestra_o_maestre(team)

        if quante_maestre(team) > 1
            return "Le maestre"
        else
            return "La maestra"
        end
    end

    def pluralize_stato_adozione(adozione)

        if adozione.stato_adozione == "adottano" || adozione.stato_adozione == "adotta"

            if quante_maestre(adozione.team) > 1
                return "adottano"
            else
                return "adotta"
            end
        else
            return adozione.stato_adozione
        end

    end
    

end
