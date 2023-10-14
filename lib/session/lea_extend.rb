module Termin
  module Session
    class LeaExtend < BaseLeaSession
      def form
        Form.new(self, [
          { name: 'sel_staat', value: 'China' },
          { name: 'personenAnzahl_normal', value: 'one person' },
          { name: 'lebnBrMitFmly', value: 'yes' },
          { name: 'fmlyMemNationality', value: 'Canada' },
          { css: '[for="SERVICEWAHL_EN3479-0-2"]' },
          { css: '[for="SERVICEWAHL_EN_479-0-2-4"]' },
          { css: '[for="SERVICEWAHL_EN479-0-2-4-305289"]' }
        ])
      end
    end
  end
end
