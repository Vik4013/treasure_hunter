defmodule TreasureHunter.Tron.Addresses do
  alias Cryptopunk.Crypto.Tron
  alias TreasureHunter.Wallet

  @path "m/44'/195'/0'/0/0"

  @spec generate(String.t()) :: :ok
  def generate(mnemonic) do
    create_address(mnemonic)
  end

  defp create_address(mnemonic) do
    master_key = Wallet.create_master_key(mnemonic.mnemonic)
    {:ok, path} = Cryptopunk.parse_path(@path)
    derived_key = Cryptopunk.derive_key(master_key, path)

    address = Tron.address(derived_key)

    params = %{address: address, path: @path, mnemonic_id: mnemonic.id}

    Wallet.create_address!(params, :tron)

    :ok
  end
end
