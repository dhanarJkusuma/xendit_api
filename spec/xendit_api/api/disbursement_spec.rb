require 'spec_helper'
require 'securerandom'

RSpec.describe XenditApi::Api::Disbursement do
  let(:client) { XenditApi::Client.new }

  describe '#create' do
    context 'with valid params' do
      it 'returns expected response' do
        VCR.use_cassette('xendit/disbursement/create/success') do
          disbursement_api = described_class.new(client)
          response = disbursement_api.create(
            external_id: SecureRandom.uuid,
            amount: 15_000,
            bank_code: 'BCA',
            account_holder_name: 'Bob Jones',
            account_number: '1111111111',
            disbursement_description: 'Payment'
          )
          expect(response).to be_instance_of XenditApi::Model::Disbursement
          expect(response).to have_attributes(
            amount: 15_000,
            bank_code: 'BCA',
            account_holder_name: 'Bob Jones',
            status: 'PENDING',
            disbursement_description: 'sample disbursement'
          )
          expect(response.external_id).not_to be_nil
          expect(response.id).not_to be_nil
        end
      end

      it 'returns expected response with for-user-id' do
        VCR.use_cassette('xendit/disbursement/create/for_user_id') do
          disbursement_api = described_class.new(client)
          headers = { for_user_id: '5785e6334d7b410667d355c4' }

          response = disbursement_api.create(
            { external_id: SecureRandom.uuid,
              amount: 15_000,
              bank_code: 'BCA',
              account_holder_name: 'Bob Jones',
              account_number: '1111111111',
              disbursement_description: 'Payment' },
            headers
          )
          expect(response).to be_instance_of XenditApi::Model::Disbursement
          expect(response).to have_attributes(
            amount: 15_000,
            bank_code: 'BCA',
            account_holder_name: 'Bob Jones',
            status: 'PENDING',
            disbursement_description: 'sample disbursement'
          )
          expect(response.external_id).not_to be_nil
          expect(response.id).not_to be_nil
        end
      end
    end

    context 'with invalid params' do
      it 'raise errors when bank code not registered' do
        error_payload = { 'error_code' => 'BANK_CODE_NOT_SUPPORTED_ERROR', 'message' => 'Bank code is not supported' }
        VCR.use_cassette('xendit/disbursement/create/bank_code_not_supported_error') do
          disbursement_api = described_class.new(client)
          expect do
            disbursement_api.create(
              external_id: SecureRandom.uuid,
              amount: 15_000,
              bank_code: 'NOT_FOUND',
              account_holder_name: 'Bob Jones',
              account_number: '1111111111',
              disbursement_description: 'sample disbursement'
            )
          end.to raise_error do |error|
            expect(error).to be_kind_of(XenditApi::Errors::Disbursement::BankCodeNotSupported)
            expect(error.message).to eq 'Bank code is not supported'
            expect(error.payload).to eq error_payload
          end
        end
      end

      it 'raise error when got INVALID_DESTINATION' do
        VCR.use_cassette('xendit/disbursement/create/invalid_destination_error') do
          error_payload = { 'error_code' => 'INVALID_DESTINATION', 'message' => 'Invalid destination' }
          instance_double('response', success?: false, error_payload: error_payload)
          disbursement_api = described_class.new(client)

          allow(disbursement_api).to receive(:create).and_raise(
            XenditApi::Errors::Disbursement::InvalidDestination.new('Invalid destination', error_payload)
          )

          expect do
            disbursement_api.create(
              external_id: SecureRandom.uuid,
              amount: 10_000_000,
              bank_code: 'MANDIRI',
              account_holder_name: 'Rizky',
              account_number: '7654321',
              disbursement_description: 'sample disbursement'
            )
          end.to raise_error do |error|
            expect(error).to be_kind_of XenditApi::Errors::Disbursement::InvalidDestination
            expect(error.message).to eq 'Invalid destination'
            expect(error.payload).to eq error_payload
          end
        end
      end

      it 'raise errors when got DISBURSEMENT_DESCRIPTION_NOT_FOUND_ERROR' do
        error_payload = { 'error_code' => 'DISBURSEMENT_DESCRIPTION_NOT_FOUND_ERROR', 'message' => 'Direct disbursement not found' }
        VCR.use_cassette('xendit/disbursement/create/disbursement_description_not_found_error') do
          disbursement_api = described_class.new(client)
          expect do
            disbursement_api.create(
              external_id: SecureRandom.uuid,
              amount: 15_000,
              bank_code: 'BCA',
              account_holder_name: 'Bob Jones',
              account_number: '1111111111',
              disbursement_description: nil
            )
          end.to raise_error do |error|
            expect(error).to be_kind_of XenditApi::Errors::Disbursement::DescriptionNotFound
            expect(error.message).to eq 'Direct disbursement not found'
            expect(error.payload).to eq error_payload
          end
        end
      end

      it 'raise errors when got DIRECT_DISBURSEMENT_BALANCE_INSUFFICIENT_ERROR' do
        error_payload = { 'error_code' => 'DIRECT_DISBURSEMENT_BALANCE_INSUFFICIENT_ERROR', 'message' => 'Balance is insufficient' }
        VCR.use_cassette('xendit/disbursement/create/disbursement_not_enough_balance_error') do
          disbursement_api = described_class.new(client)
          expect do
            disbursement_api.create(
              external_id: SecureRandom.uuid,
              amount: 1_000_000_000_000,
              bank_code: 'BCA',
              account_holder_name: 'Bob Jones',
              account_number: '1111111111',
              disbursement_description: 'sample disbursement'
            )
          end.to raise_error do |error|
            expect(error).to be_kind_of XenditApi::Errors::Disbursement::NotEnoughBalance
            expect(error.message).to eq 'Balance is insufficient'
            expect(error.payload).to eq error_payload
          end
        end
      end

      it 'raise erorrs when got DUPLICATE_TRANSACTION_ERROR' do
        error_payload = { 'error_code' => 'DUPLICATE_TRANSACTION_ERROR', 'message' => 'Disbursement was duplicated' }
        VCR.use_cassette('xendit/disbursement/create/duplicate_transaction_error') do
          disbursement_api = described_class.new(client)
          expect do
            disbursement_api.create(
              external_id: SecureRandom.uuid,
              amount: 100_000,
              bank_code: 'BCA',
              account_holder_name: 'Bob Jones',
              account_number: '1111111111',
              disbursement_description: 'sample disbursement'
            )
          end.to raise_error do |error|
            expect(error).to be_kind_of XenditApi::Errors::Disbursement::DuplicateTransactionError
            expect(error.message).to eq 'Disbursement was duplicated'
            expect(error.payload).to eq error_payload
          end
        end
      end

      it 'raise error when got RECIPIENT_ACCOUNT_NUMBER_ERROR' do
        error_payload = { 'error_code' => 'RECIPIENT_ACCOUNT_NUMBER_ERROR', 'message' => 'BCA account numbers must be 10 digits long' }
        VCR.use_cassette('xendit/disbursement/create/recipient_account_number_error') do
          disbursement_api = described_class.new(client)
          expect do
            disbursement_api.create(
              external_id: SecureRandom.uuid,
              amount: 100_000,
              bank_code: 'BCA',
              account_holder_name: 'Bob Jones',
              account_number: '123',
              disbursement_description: 'sample disbursement'
            )
          end.to raise_error do |error|
            expect(error).to be_kind_of XenditApi::Errors::Disbursement::RecipientAccountNumberError
            expect(error.message).to eq 'BCA account numbers must be 10 digits long'
            expect(error.payload).to eq error_payload
          end
        end
      end

      it 'raise error when got RECIPIENT_AMOUNT_ERROR' do
        error_payload = { 'error_code' => 'RECIPIENT_AMOUNT_ERROR', 'message' => 'Recipient amount error' }
        VCR.use_cassette('xendit/disbursement/create/recipient_amount_error') do
          disbursement_api = described_class.new(client)
          expect do
            disbursement_api.create(
              external_id: SecureRandom.uuid,
              amount: 1,
              bank_code: 'BCA',
              account_holder_name: 'Bob Jones',
              account_number: '1111111111',
              disbursement_description: 'sample disbursement'
            )
          end.to raise_error do |error|
            expect(error).to be_kind_of XenditApi::Errors::Disbursement::RecipientAmountError
            expect(error.message).to eq 'Recipient amount error'
            expect(error.payload).to eq error_payload
          end
        end
      end

      it 'raise error when got MAXIMUM_TRANSFER_LIMIT_ERROR' do
        error_payload = { 'error_code' => 'MAXIMUM_TRANSFER_LIMIT_ERROR', 'message' => 'Maximum transfer limit error' }
        VCR.use_cassette('xendit/disbursement/create/maximum_transfer_limit_error') do
          disbursement_api = described_class.new(client)
          expect do
            disbursement_api.create(
              external_id: SecureRandom.uuid,
              amount: 10_000_000,
              bank_code: 'BCA',
              account_holder_name: 'Bob Jones',
              account_number: '1111111111',
              disbursement_description: 'sample disbursement'
            )
          end.to raise_error do |error|
            expect(error).to be_kind_of XenditApi::Errors::Disbursement::MaximumTransferLimitError
            expect(error.message).to eq 'Maximum transfer limit error'
            expect(error.payload).to eq error_payload
          end
        end
      end

      it 'raise error when got SWITCHING_NETWORK_ERROR' do
        error_payload = { 'error_code' => 'SWITCHING_NETWORK_ERROR', 'message' => 'Switching network error' }
        VCR.use_cassette('xendit/disbursement/create/switching_network_error') do
          disbursement_api = described_class.new(client)
          expect do
            disbursement_api.create(
              external_id: SecureRandom.uuid,
              amount: 10_000_000,
              bank_code: 'MANDIRI',
              account_holder_name: 'Siti',
              account_number: '12121212',
              disbursement_description: 'sample disbursement'
            )
          end.to raise_error do |error|
            expect(error).to be_kind_of XenditApi::Errors::Disbursement::SwitchingNetworkError
            expect(error.message).to eq 'Switching network error'
            expect(error.payload).to eq error_payload
          end
        end
      end

      it 'raise error when got UNKNOWN_BANK_NETWORK_ERROR' do
        error_payload = { 'error_code' => 'UNKNOWN_BANK_NETWORK_ERROR', 'message' => 'Unknown bank network error' }
        VCR.use_cassette('xendit/disbursement/create/unkown_bank_network_error') do
          disbursement_api = described_class.new(client)
          expect do
            disbursement_api.create(
              external_id: SecureRandom.uuid,
              amount: 10_000_000,
              bank_code: 'MANDIRI',
              account_holder_name: 'Andri',
              account_number: '987654321',
              disbursement_description: 'sample disbursement'
            )
          end.to raise_error do |error|
            expect(error).to be_kind_of XenditApi::Errors::Disbursement::UnknownBankNetworkError
            expect(error.message).to eq 'Unknown bank network error'
            expect(error.payload).to eq error_payload
          end
        end
      end

      it 'raise error when got TEMPORARY_BANK_NETWORK_ERROR' do
        error_payload = { 'error_code' => 'TEMPORARY_BANK_NETWORK_ERROR', 'message' => 'Temporary bank network error' }
        VCR.use_cassette('xendit/disbursement/create/temporary_bank_network_error') do
          disbursement_api = described_class.new(client)
          expect do
            disbursement_api.create(
              external_id: SecureRandom.uuid,
              amount: 10_000_000,
              bank_code: 'MANDIRI',
              account_holder_name: 'Yono',
              account_number: '321321321',
              disbursement_description: 'sample disbursement'
            )
          end.to raise_error do |error|
            expect(error).to be_kind_of XenditApi::Errors::Disbursement::TemporaryBankNetworkError
            expect(error.message).to eq 'Temporary bank network error'
            expect(error.payload).to eq error_payload
          end
        end
      end

      it 'raise error when got REJECTED_BY_BANK' do
        error_payload = { 'error_code' => 'REJECTED_BY_BANK', 'message' => 'Rejected by bank error' }
        VCR.use_cassette('xendit/disbursement/create/rejected_by_bank_error') do
          disbursement_api = described_class.new(client)
          expect do
            disbursement_api.create(
              external_id: SecureRandom.uuid,
              amount: 10_000_000,
              bank_code: 'MANDIRI',
              account_holder_name: 'Budi',
              account_number: '8787878',
              disbursement_description: 'sample disbursement'
            )
          end.to raise_error do |error|
            expect(error).to be_kind_of XenditApi::Errors::Disbursement::RejectedByBank
            expect(error.message).to eq 'Rejected by bank error'
            expect(error.payload).to eq error_payload
          end
        end
      end

      it 'raise error when got TRANSFER_ERROR' do
        error_payload = { 'error_code' => 'TRANSFER_ERROR', 'message' => 'Transfer error' }
        VCR.use_cassette('xendit/disbursement/create/transfer_error') do
          disbursement_api = described_class.new(client)
          expect do
            disbursement_api.create(
              external_id: SecureRandom.uuid,
              amount: 10_000_000,
              bank_code: 'MANDIRI',
              account_holder_name: 'Adnin',
              account_number: '1351357',
              disbursement_description: 'sample disbursement'
            )
          end.to raise_error do |error|
            expect(error).to be_kind_of XenditApi::Errors::Disbursement::TransferError
            expect(error.message).to eq 'Transfer error'
            expect(error.payload).to eq error_payload
          end
        end
      end

      it 'raise error when got TEMPORARY_TRANSFER_ERROR' do
        error_payload = { 'error_code' => 'TEMPORARY_TRANSFER_ERROR', 'message' => 'Temporary transfer error' }
        VCR.use_cassette('xendit/disbursement/create/temporary_transfer_error') do
          disbursement_api = described_class.new(client)
          expect do
            disbursement_api.create(
              external_id: SecureRandom.uuid,
              amount: 10_000_000,
              bank_code: 'MANDIRI',
              account_holder_name: 'Sutiono',
              account_number: '868686',
              disbursement_description: 'sample disbursement'
            )
          end.to raise_error do |error|
            expect(error).to be_kind_of XenditApi::Errors::Disbursement::TemporaryTransferError
            expect(error.message).to eq 'Temporary transfer error'
            expect(error.payload).to eq error_payload
          end
        end
      end

      it 'raise error when got INSUFFICIENT_BALANCE' do
        error_payload = { 'error_code' => 'INSUFFICIENT_BALANCE', 'message' => 'Insufficient balance' }
        VCR.use_cassette('xendit/disbursement/create/insufficient_balance') do
          disbursement_api = described_class.new(client)
          expect do
            disbursement_api.create(
              external_id: SecureRandom.uuid,
              amount: 10_000_000,
              bank_code: 'MANDIRI',
              account_holder_name: 'Sutiono',
              account_number: '868686',
              disbursement_description: 'sample disbursement'
            )
          end.to raise_error do |error|
            expect(error).to be_kind_of XenditApi::Errors::Disbursement::NotEnoughBalance
            expect(error.message).to eq 'Insufficient balance'
            expect(error.payload).to eq error_payload
          end
        end
      end
    end
  end

  describe '#find_by_external_id' do
    context 'with valid external_id' do
      it 'returns expected response' do
        VCR.use_cassette('xendit/disbursement/find_by_external_id/200_ok') do
          disbursement_api = described_class.new(client)
          disbursement = disbursement_api.find_by_external_id('d28aac6a-03c8-46d0-ac03-43b6278b35eb')
          expect(disbursement).to be_kind_of XenditApi::Model::Disbursement
          expect(disbursement.external_id).to eq 'd28aac6a-03c8-46d0-ac03-43b6278b35eb'
          expect(disbursement.amount).not_to be_nil
          expect(disbursement.bank_code).not_to be_nil
          expect(disbursement.user_id).not_to be_nil
          expect(disbursement.account_holder_name).not_to be_nil
          expect(disbursement.status).not_to be_nil
          expect(disbursement.id).not_to be_nil
          expect(disbursement.payload).not_to be_nil
        end
      end

      it 'returns the last disbursement record when has multiple' do
        VCR.use_cassette('xendit/disbursement/find_by_external_id/multiple') do
          disbursement_api = described_class.new(client)
          disbursement = disbursement_api.find_by_external_id('sample-external-id')
          expect(disbursement).to be_kind_of XenditApi::Model::Disbursement
          expect(disbursement.external_id).to eq 'sample-external-id'
          expect(disbursement.amount).to eq 200_000
          expect(disbursement.bank_code).not_to be_nil
          expect(disbursement.user_id).not_to be_nil
          expect(disbursement.account_holder_name).not_to be_nil
          expect(disbursement.status).not_to be_nil
          expect(disbursement.id).not_to be_nil
          expect(disbursement.payload).not_to be_nil
        end
      end
    end

    context 'with invalid external id' do
      it 'returns expected response' do
        error_payload = { 'error_code' => 'DIRECT_DISBURSEMENT_NOT_FOUND_ERROR', 'message' => 'Direct disbursement not found' }
        VCR.use_cassette('xendit/disbursement/find_by_external_id/invalid') do
          disbursement_api = described_class.new(client)

          expect do
            disbursement_api.find_by_external_id('d666', {})
          end.to raise_error do |error|
            expect(error).to be_kind_of XenditApi::Errors::Disbursement::DirectDisbursementNotFound
            expect(error.message).to eq 'Direct disbursement not found'
            expect(error.payload).to eq error_payload
          end
        end
      end
    end
  end

  describe '#where_by_external_id' do
    it 'returns expected disbursements' do
      VCR.use_cassette('xendit/disbursement/where_by_external_id/two_records') do
        disbursement_api = described_class.new(client)
        disbursements = disbursement_api.where_by_external_id('sample-external-id', {})
        expect(disbursements.size).to eq 2
        first_disbursement = disbursements.first
        expect(first_disbursement).to be_kind_of XenditApi::Model::Disbursement
        expect(first_disbursement.external_id).to eq 'sample-external-id'
        expect(first_disbursement.amount).not_to be_nil
        expect(first_disbursement.bank_code).not_to be_nil
        expect(first_disbursement.user_id).not_to be_nil
        expect(first_disbursement.account_holder_name).not_to be_nil
        expect(first_disbursement.status).not_to be_nil
        expect(first_disbursement.id).not_to be_nil
        expect(first_disbursement.payload).not_to be_nil
        second_disbursement = disbursements.last
        expect(second_disbursement).to be_kind_of XenditApi::Model::Disbursement
        expect(second_disbursement.external_id).to eq 'sample-external-id'
        expect(second_disbursement.amount).not_to be_nil
        expect(second_disbursement.bank_code).not_to be_nil
        expect(second_disbursement.user_id).not_to be_nil
        expect(second_disbursement.account_holder_name).not_to be_nil
        expect(second_disbursement.status).not_to be_nil
        expect(second_disbursement.id).not_to be_nil
        expect(second_disbursement.payload).not_to be_nil
      end
    end

    it 'raise error when disbursement was not found' do
      VCR.use_cassette('xendit/disbursement/where_by_external_id/not_found') do
        error_payload = { 'error_code' => 'DIRECT_DISBURSEMENT_NOT_FOUND_ERROR', 'message' => 'Direct disbursement not found' }
        disbursement_api = described_class.new(client)
        expect do
          disbursement_api.where_by_external_id('d666', {})
        end.to raise_error do |error|
          expect(error).to be_kind_of XenditApi::Errors::Disbursement::DirectDisbursementNotFound
          expect(error.message).to eq 'Direct disbursement not found'
          expect(error.payload).to eq error_payload
        end
      end
    end
  end
end
