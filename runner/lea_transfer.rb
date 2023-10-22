module Termin
  module Runner
    class LeaTransfer < Session::BaseLeaSession
      def form
        Session::Form.new(self, [
          { name: 'sel_staat', value: 'Canada' },
          { name: 'personenAnzahl_normal', value: 'one person' },
          { name: 'lebnBrMitFmly', value: 'yes' },
          { name: 'fmlyMemNationality', value: 'China' },
          { css: '[for="SERVICEWAHL_EN3348-0-3"]' },
          { css: '[for="SERVICEWAHL_EN348-0-3-99-324280"]' }
        ])
      end
    end
  end
end
