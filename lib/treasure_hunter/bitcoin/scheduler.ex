defmodule TreasureHunter.Bitcoin.Scheduler do
  alias Cryptopunk.Crypto.Bitcoin
  alias TreasureHunter.Wallet

  @legacy_path "m/44'/0'"
  @bech32_path "m/84'/0'"
  @p2sh_p2wpkh_path "m/49'/0'"
  @mnemonic_lengths [12, 15, 18, 21, 24]
  @network :mainnet
  @seed_type :bip39

  def create_addresses_from_naive_mnemonics do
    mnemonics = create_mnemonics()
    crypto = fetch_crypto()

    Enum.each(mnemonics, fn mnemonic ->
      create_legacy_addresses(mnemonic, crypto)
      create_legacy_uncompressed_addresses(mnemonic, crypto)
      create_bech32_addresses(mnemonic, crypto)
      create_p2sh_p2wpkh_addresses(mnemonic, crypto)
    end)
  end

  defp create_legacy_addresses(mnemonic, crypto) do
    address_func = fn key ->
      Bitcoin.legacy_address(key, @network)
    end

    create_addresses(@legacy_path, mnemonic, crypto, address_func)
  end

  defp create_legacy_uncompressed_addresses(mnemonic, crypto) do
    address_func = fn key ->
      Bitcoin.legacy_address(key, @network, uncompressed: true)
    end

    create_addresses(@legacy_path, mnemonic, crypto, address_func, %{uncompressed: true})
  end

  defp create_bech32_addresses(mnemonic, crypto) do
    address_func = fn key ->
      Bitcoin.bech32_address(key, @network)
    end

    create_addresses(@bech32_path, mnemonic, crypto, address_func)
  end

  defp create_p2sh_p2wpkh_addresses(mnemonic, crypto) do
    address_func = fn key ->
      Bitcoin.p2sh_p2wpkh_address(key, @network)
    end

    create_addresses(@p2sh_p2wpkh_path, mnemonic, crypto, address_func)
  end

  def create_mnemonics do
    words = Wallet.mnemonic_words()

    Enum.flat_map(words, fn word ->
      Enum.map(@mnemonic_lengths, fn length ->
        mnemonic =
          word
          |> List.duplicate(length)
          |> Enum.join(" ")

        params = %{mnemonic: mnemonic, type: @seed_type}
        Wallet.fetch_or_create_mnemonic!(params)
      end)
    end)
  end

  defp create_addresses(path_prefix, mnemonic, crypto, address_func, additional_params \\ %{}) do
    master_key = create_master_key(mnemonic.mnemonic)
    raw_paths = create_raw_paths(path_prefix)

    Enum.each(raw_paths, fn raw_path ->
      {:ok, path} = Cryptopunk.parse_path(raw_path)
      derived_key = Cryptopunk.derive_key(master_key, path)

      address = address_func.(derived_key)

      params =
        Map.merge(
          %{address: address, path: raw_path, crypto_id: crypto.id, mnemonic_id: mnemonic.id},
          additional_params
        )

      Wallet.create_address!(params)
    end)
  end

  defp create_master_key(mnemonic) do
    mnemonic
    |> Cryptopunk.create_seed()
    |> Cryptopunk.master_key_from_seed()
  end

  defp create_raw_paths(path_prefix) do
    accounts = 2
    changes = 1
    idxs = 2

    Enum.flat_map(0..accounts, fn account ->
      Enum.flat_map(0..idxs, fn idx ->
        Enum.map(0..changes, fn change ->
          path_prefix <> "/#{account}'/#{change}/#{idx}"
        end)
      end)
    end)
  end

  defp fetch_crypto do
    Wallet.fetch_or_create_crypto!(:bitcoin)
  end
end
