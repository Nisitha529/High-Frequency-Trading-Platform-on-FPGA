library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reset_idelayctrl is
    generic (
        kDlyRstDelay : integer := 8
    );
    port (
        RefClk   : in  std_logic;
        rIntRst  : in  std_logic;
        rDlyRst  : out std_logic
    );
end entity reset_idelayctrl;

architecture rtl of reset_idelayctrl is
    signal rDlyRstCnt : integer range 0 to kDlyRstDelay - 1 := 0;
    signal rDlyRst_i  : std_logic := '0';
begin
    ResetIDELAYCTRL : process(RefClk)
    begin
        if rising_edge(RefClk) then
            if (rIntRst = '1') then
                rDlyRstCnt <= kDlyRstDelay - 1;
                rDlyRst_i  <= '1';
--            elsif (rDlyRstCnt /= 0) then
                
            else
                if (rDlyRstCnt /= 0) then
                  rDlyRstCnt <= rDlyRstCnt - 1;
                else 
                  rDlyRst_i  <= '0';
                end if;
            end if;
        end if;
    end process;

    rDlyRst <= rDlyRst_i;

end architecture rtl;
