function [cipher_image_roi_encrypted, plain_image_decrypted] = parallel_encrypt_decrypt( ...
    plain_image_path, ...
    N_psrd, ...
    saliency_method, ...
    saliency_threshold, ...
    chaos_params, ...
    perform_encryption, ...
    perform_decryption, ...
    ciphered_image_for_decryption) % Optional: for decryption only
% parallel_encrypt_decrypt: Main function to demonstrate ROI encryption and decryption.
%
% Args:
%   plain_image_path (str): Path to the plain image.
%   N_psrd (int): N for PSRD (N x N patches).
%   saliency_method (str): Method for detect_saliency.m.
%   saliency_threshold (float or 'auto'): Threshold for binarizing saliency map.
%   chaos_params (struct): Parameters for chaotic maps (LICC, Logistic).
%       Fields should include:
%         licc_x0, licc_y0, licc_z0, licc_a, licc_b, licc_c
%         logistic_lambda_grouping, logistic_x0_grouping
%         logistic_lambda_shuffling, logistic_x0_shuffling (can be same as grouping)
%         T_discard
%   perform_encryption (logical): If true, run encryption.
%   perform_decryption (logical): If true, run decryption.
%   ciphered_image_for_decryption (matrix, optional): If only decrypting, provide this.
%
% Returns:
%   cipher_image_roi_encrypted (matrix): Image with ROIs encrypted.
%   plain_image_decrypted (matrix): Decrypted image (should match original if all goes well).

    % Add paths to helper functions (if not already on Matlab path)
    % This might be better handled by a startup script or running from parent dir
    if ~isdeployed
        addpath(genpath('../chaos_systems')); % Relative path, adjust if needed
        addpath(genpath('../roi_detection'));
    end

    L_value = 256; % For 8-bit images

    % --- Initialize outputs ---
    cipher_image_roi_encrypted = [];
    plain_image_decrypted = [];

    % --- Load Plain Image ---
    try
        plain_image_uint8 = imread(plain_image_path);
        if size(plain_image_uint8,3) ~=3
            error('This scheme is designed for RGB images.');
        end
    catch ME
        error('Failed to load plain image: %s. Error: %s', plain_image_path, ME.message);
    end

    plain_image_for_decryption = plain_image_uint8; % Keep a copy for final comparison if decrypting

    % --- Encryption Process ---
    if perform_encryption
        fprintf('--- Starting Encryption Process ---\n');

        % 1. ROI Detection using EDN-lite (simulated) and PSRD
        fprintf('1. Detecting ROIs...\n');
        saliency_map_binary = detect_saliency(plain_image_path, saliency_method, saliency_threshold);
        ROI_info = psrd(saliency_map_binary, N_psrd);

        % Visualize ROI_info on original image (optional)
        % figure; imshow(plain_image_uint8); hold on;
        % for k=1:length(ROI_info)
        %     if ROI_info(k).has_roi, rectangle('Position',ROI_info(k).roi_rect,'EdgeColor','r'); end
        % end
        % title('Detected ROIs on Original Image'); hold off;

        % 2. Pixel Extraction and Grouping (Alg. 2)
        fprintf('2. Extracting and grouping pixels from ROIs...\n');
        [seq0_plain, seq1_plain, seq2_plain, index_seg_shuffled, total_roi_pixels] = ...
            extract_pixels(plain_image_uint8, ROI_info, N_psrd, chaos_params);

        if total_roi_pixels == 0
            warning('No ROIs detected or no pixels in ROIs. Encryption cannot proceed.');
            cipher_image_roi_encrypted = plain_image_uint8; % Return original if no ROI
            if ~perform_decryption % If only encryption was requested
                return;
            end
        else
            fprintf('Total ROI pixels to encrypt: %d\n', total_roi_pixels);
            fprintf('Length of plain sequences: s0=%d, s1=%d, s2=%d\n', length(seq0_plain), length(seq1_plain), length(seq2_plain));
        end

        % 3. Multi-channel Parallel Encryption (Alg. 3 & 4)
        fprintf('3. Performing multi-channel parallel encryption...\n');
        num_pixels_per_seq = total_roi_pixels;

        % Generate LICC chaotic sequences for encryption
        % Each sequence chao_j needs to be of length num_pixels_per_seq
        [chao0_x, chao0_y, chao0_z] = licc_system(chaos_params.licc_x0, chaos_params.licc_y0, chaos_params.licc_z0, ...
                                                 chaos_params.licc_a, chaos_params.licc_b, chaos_params.licc_c, ...
                                                 num_pixels_per_seq, chaos_params.T_discard);
        % For simplicity, using only one component of LICC for each channel's chaotic sequence, or combine them.
        % Paper is not explicit. Let's use x for chao0, y for chao1, z for chao2.
        % Ensure they are scaled appropriately if needed (e.g. to generate indices or keys).
        % Here, chao_j is used to derive k_sele and permutation indices.
        chao0_stream = chao0_x;
        chao1_stream = chao0_y; % Re-use for simplicity, or generate independently
        chao2_stream = chao0_z;

        if length(chao0_stream) < num_pixels_per_seq || length(chao1_stream) < num_pixels_per_seq || length(chao2_stream) < num_pixels_per_seq
             error('LICC system did not generate enough chaotic values for all sequences.');
        end

        % Encrypt each sequence (simulating parallel)
        % Alg.3: ENCRYPTION(chao_j, seq_j)
        cseq0_cipher = encrypt_channel(seq0_plain, chao0_stream(1:num_pixels_per_seq), L_value);
        cseq1_cipher = encrypt_channel(seq1_plain, chao1_stream(1:num_pixels_per_seq), L_value);
        cseq2_cipher = encrypt_channel(seq2_plain, chao2_stream(1:num_pixels_per_seq), L_value);

        fprintf('Encryption of channels complete.\n');

        % 4. Write ciphered pixel data back to image
        fprintf('4. Writing ciphered pixels back to image...\n');
        cipher_image_roi_encrypted = plain_image_uint8; % Start with a copy of the original

        % This part needs the inverse of extract_pixels logic for placing data
        % We need to know which (r,c) corresponds to which index in cseq0,cseq1,cseq2
        % This requires knowing the original grouping rules and shuffled patch order.
        % The `extract_pixels` function used `grouping_rules` derived from `chaoseq_logi`.
        % We need that `chaoseq_logi` here or regenerate it.

        num_rules_enc = floor(total_roi_pixels / 3);
        chaoseq_logi_enc = logistic_map(chaos_params.logistic_x0_grouping, ...
                                    chaos_params.logistic_lambda_grouping, ...
                                    num_rules_enc, chaos_params.T_discard);
        grouping_rules_enc = floor(abs(chaoseq_logi_enc) * 6);
        grouping_rules_enc = mod(grouping_rules_enc, 6);

        pixel_write_count = 0;
        for k_patch_shuffled = 1:length(index_seg_shuffled)
            current_patch_original_index = index_seg_shuffled(k_patch_shuffled);
            info_entry = [];
            for r_info_idx = 1:length(ROI_info)
                if ROI_info(r_info_idx).patch_index == current_patch_original_index
                    info_entry = ROI_info(r_info_idx);
                    break;
                end
            end

            if isempty(info_entry) || ~info_entry.has_roi || isempty(info_entry.roi_rect)
                continue;
            end

            rect = info_entry.roi_rect;
            min_col = rect(1); min_row = rect(2);
            max_col = rect(1) + rect(3) - 1;
            max_row = rect(2) + rect(4) - 1;

            for r_idx = min_row:max_row
                for c_idx = min_col:max_col
                    pixel_write_count = pixel_write_count + 1;
                    if pixel_write_count > total_roi_pixels
                        error('Pixel write count exceeds total ROI pixels during encryption write-back.');
                    end

                    % Get the encrypted components for this pixel
                    val_s0 = cseq0_cipher(pixel_write_count);
                    val_s1 = cseq1_cipher(pixel_write_count);
                    val_s2 = cseq2_cipher(pixel_write_count);

                    % Determine original R,G,B based on the INVERSE of Table 3 rule
                    current_rule_idx_enc = mod(pixel_write_count-1, num_rules_enc) + 1;
                    rule_enc = grouping_rules_enc(current_rule_idx_enc);

                    % Table 4: Pixels allocation rule in decryption stage (inverse of Table 3)
                    % rule0 (s0=R,s1=G,s2=B) -> R=s0, G=s1, B=s2
                    % rule1 (s0=R,s1=B,s2=G) -> R=s0, G=s2, B=s1
                    % ... and so on
                    if rule_enc == 0 % s0=R, s1=G, s2=B
                        cipher_image_roi_encrypted(r_idx, c_idx, 1) = val_s0;
                        cipher_image_roi_encrypted(r_idx, c_idx, 2) = val_s1;
                        cipher_image_roi_encrypted(r_idx, c_idx, 3) = val_s2;
                    elseif rule_enc == 1 % s0=R, s1=B, s2=G
                        cipher_image_roi_encrypted(r_idx, c_idx, 1) = val_s0;
                        cipher_image_roi_encrypted(r_idx, c_idx, 2) = val_s2;
                        cipher_image_roi_encrypted(r_idx, c_idx, 3) = val_s1;
                    elseif rule_enc == 2 % s0=G, s1=R, s2=B
                        cipher_image_roi_encrypted(r_idx, c_idx, 1) = val_s1;
                        cipher_image_roi_encrypted(r_idx, c_idx, 2) = val_s0;
                        cipher_image_roi_encrypted(r_idx, c_idx, 3) = val_s2;
                    elseif rule_enc == 3 % s0=G, s1=B, s2=R
                        cipher_image_roi_encrypted(r_idx, c_idx, 1) = val_s2; % R=s2
                        cipher_image_roi_encrypted(r_idx, c_idx, 2) = val_s0; % G=s0
                        cipher_image_roi_encrypted(r_idx, c_idx, 3) = val_s1; % B=s1
                    elseif rule_enc == 4 % s0=B, s1=R, s2=G
                        cipher_image_roi_encrypted(r_idx, c_idx, 1) = val_s1; % R=s1
                        cipher_image_roi_encrypted(r_idx, c_idx, 2) = val_s2; % G=s2
                        cipher_image_roi_encrypted(r_idx, c_idx, 3) = val_s0; % B=s0
                    elseif rule_enc == 5 % s0=B, s1=G, s2=R
                        cipher_image_roi_encrypted(r_idx, c_idx, 1) = val_s2; % R=s2
                        cipher_image_roi_encrypted(r_idx, c_idx, 2) = val_s1; % G=s1
                        cipher_image_roi_encrypted(r_idx, c_idx, 3) = val_s0; % B=s0
                    end
                end
            end
        end
        fprintf('Encryption complete. Cipher image with encrypted ROIs generated.\n');

        % 5. Data Steganography (Placeholder - Not fully implemented due to complexity)
        % ROI_info and index_seg_shuffled would be embedded here.
        % For now, these will be passed directly to decryption if needed.
        fprintf('5. Data steganography (embedding ROI_info) is a placeholder.\n');
        % embedded_image = reversible_data_hiding_embed(cipher_image_roi_encrypted, ROI_info, index_seg_shuffled, steg_params);
        % For now, cipher_image_roi_encrypted is the final encrypted output.
    end % End of encryption block

    % --- Decryption Process ---
    if perform_decryption
        fprintf('--- Starting Decryption Process ---\n');

        if ~perform_encryption && isempty(ciphered_image_for_decryption)
            error('For decryption, either encrypt first or provide ciphered_image_for_decryption.');
        end

        if perform_encryption
            image_to_decrypt = cipher_image_roi_encrypted;
            % In a full system, ROI_info_dec and index_seg_shuffled_dec would be extracted via steganography
            ROI_info_dec = ROI_info; % Passed directly for this version
            index_seg_shuffled_dec = index_seg_shuffled; % Passed directly
            total_roi_pixels_dec = total_roi_pixels; % Passed directly
        else
            image_to_decrypt = ciphered_image_for_decryption;
            % If only decrypting, ROI_info and index_seg_shuffled must be known or loaded.
            % This simplified version assumes they are available or re-derived if possible.
            % For a standalone decryption, these would need to be loaded from a file or extracted.
            % We'll re-run ROI detection to get ROI_info for standalone decryption.
            % This is not ideal as the original ROI_info is what's needed.
            % For this example, we'll assume ROI_info is known or passed.
            % This is a limitation of not having steganography fully implemented.

            fprintf('Re-detecting ROIs for decryption reference (as steganography is not implemented)...\n');
            saliency_map_binary_dec = detect_saliency(plain_image_path, saliency_method, saliency_threshold); % Path to original needed
            ROI_info_dec = psrd(saliency_map_binary_dec, N_psrd);

            % Re-calculate total_roi_pixels
            total_roi_pixels_dec = 0;
            for k = 1:length(ROI_info_dec)
                if ROI_info_dec(k).has_roi && ~isempty(ROI_info_dec(k).roi_rect)
                    rect_dec = ROI_info_dec(k).roi_rect;
                    total_roi_pixels_dec = total_roi_pixels_dec + (rect_dec(3) * rect_dec(4));
                end
            end

            % Re-generate index_seg_shuffled for decryption
             num_patches_dec = N_psrd * N_psrd;
             patch_indices_dec = 1:num_patches_dec;
             shuffle_chaos_dec = logistic_map(chaos_params.logistic_x0_shuffling, ...
                                         chaos_params.logistic_lambda_shuffling, ...
                                         num_patches_dec, chaos_params.T_discard);
            [~, sorted_shuffle_indices_dec] = sort(shuffle_chaos_dec);
            index_seg_shuffled_dec = patch_indices_dec(sorted_shuffle_indices_dec);
        end

        if total_roi_pixels_dec == 0
            warning('No ROIs for decryption. Returning the input image.');
            plain_image_decrypted = image_to_decrypt;
            return;
        end

        % 1. Extract ciphered pixel data from ROIs
        fprintf('1. Extracting ciphered pixels from ROIs for decryption...\n');
        % This step needs the grouping rules to know which channel from image_to_decrypt
        % corresponds to cseq0, cseq1, cseq2.
        num_rules_dec = floor(total_roi_pixels_dec / 3);
        chaoseq_logi_dec_grouping = logistic_map(chaos_params.logistic_x0_grouping, ...
                                    chaos_params.logistic_lambda_grouping, ...
                                    num_rules_dec, chaos_params.T_discard);
        grouping_rules_dec_extract = floor(abs(chaoseq_logi_dec_grouping) * 6);
        grouping_rules_dec_extract = mod(grouping_rules_dec_extract, 6);

        cseq0_extracted = zeros(1, total_roi_pixels_dec, 'uint8');
        cseq1_extracted = zeros(1, total_roi_pixels_dec, 'uint8');
        cseq2_extracted = zeros(1, total_roi_pixels_dec, 'uint8');
        pixel_extract_count_dec = 0;

        for k_patch_shuffled_dec = 1:length(index_seg_shuffled_dec)
            current_patch_original_index_dec = index_seg_shuffled_dec(k_patch_shuffled_dec);
            info_entry_dec = [];
             for r_info_idx = 1:length(ROI_info_dec) % Use ROI_info_dec
                if ROI_info_dec(r_info_idx).patch_index == current_patch_original_index_dec
                    info_entry_dec = ROI_info_dec(r_info_idx);
                    break;
                end
            end

            if isempty(info_entry_dec) || ~info_entry_dec.has_roi || isempty(info_entry_dec.roi_rect)
                continue;
            end

            rect_dec_extract = info_entry_dec.roi_rect;
            min_col_dec = rect_dec_extract(1); min_row_dec = rect_dec_extract(2);
            max_col_dec = rect_dec_extract(1) + rect_dec_extract(3) - 1;
            max_row_dec = rect_dec_extract(2) + rect_dec_extract(4) - 1;

            for r_idx_dec = min_row_dec:max_row_dec
                for c_idx_dec = min_col_dec:max_col_dec
                    pixel_extract_count_dec = pixel_extract_count_dec + 1;
                    if pixel_extract_count_dec > total_roi_pixels_dec
                        error('Pixel extract count exceeds total ROI pixels during decryption extract.');
                    end

                    img_R = image_to_decrypt(r_idx_dec, c_idx_dec, 1);
                    img_G = image_to_decrypt(r_idx_dec, c_idx_dec, 2);
                    img_B = image_to_decrypt(r_idx_dec, c_idx_dec, 3);

                    current_rule_idx_dec = mod(pixel_extract_count_dec-1, num_rules_dec) + 1;
                    rule_dec = grouping_rules_dec_extract(current_rule_idx_dec); % This is the rule used for encryption mapping

                    % Inverse of Table 4 (which is Table 3) to get s0, s1, s2 from R,G,B of cipher image
                    if rule_dec == 0 % Enc was (R->s0, G->s1, B->s2)
                        cseq0_extracted(pixel_extract_count_dec) = img_R;
                        cseq1_extracted(pixel_extract_count_dec) = img_G;
                        cseq2_extracted(pixel_extract_count_dec) = img_B;
                    elseif rule_dec == 1 % Enc was (R->s0, B->s1, G->s2)
                        cseq0_extracted(pixel_extract_count_dec) = img_R;
                        cseq1_extracted(pixel_extract_count_dec) = img_B;
                        cseq2_extracted(pixel_extract_count_dec) = img_G;
                    elseif rule_dec == 2 % Enc was (G->s0, R->s1, B->s2)
                        cseq0_extracted(pixel_extract_count_dec) = img_G;
                        cseq1_extracted(pixel_extract_count_dec) = img_R;
                        cseq2_extracted(pixel_extract_count_dec) = img_B;
                    elseif rule_dec == 3 % Enc was (G->s0, B->s1, R->s2)
                        cseq0_extracted(pixel_extract_count_dec) = img_G;
                        cseq1_extracted(pixel_extract_count_dec) = img_B;
                        cseq2_extracted(pixel_extract_count_dec) = img_R;
                    elseif rule_dec == 4 % Enc was (B->s0, R->s1, G->s2)
                        cseq0_extracted(pixel_extract_count_dec) = img_B;
                        cseq1_extracted(pixel_extract_count_dec) = img_R;
                        cseq2_extracted(pixel_extract_count_dec) = img_G;
                    elseif rule_dec == 5 % Enc was (B->s0, G->s1, R->s2)
                        cseq0_extracted(pixel_extract_count_dec) = img_B;
                        cseq1_extracted(pixel_extract_count_dec) = img_G;
                        cseq2_extracted(pixel_extract_count_dec) = img_R;
                    end
                end
            end
        end
        fprintf('Extraction of ciphered sequences complete.\n');

        % 2. Decrypt each sequence
        fprintf('2. Performing multi-channel parallel decryption...\n');
        num_pixels_per_seq_dec = total_roi_pixels_dec;

        [chao0_x_dec, chao0_y_dec, chao0_z_dec] = licc_system(chaos_params.licc_x0, chaos_params.licc_y0, chaos_params.licc_z0, ...
                                                     chaos_params.licc_a, chaos_params.licc_b, chaos_params.licc_c, ...
                                                     num_pixels_per_seq_dec, chaos_params.T_discard);
        chao0_stream_dec = chao0_x_dec;
        chao1_stream_dec = chao0_y_dec;
        chao2_stream_dec = chao0_z_dec;

        if length(chao0_stream_dec) < num_pixels_per_seq_dec || length(chao1_stream_dec) < num_pixels_per_seq_dec || length(chao2_stream_dec) < num_pixels_per_seq_dec
             error('LICC system did not generate enough chaotic values for all sequences during decryption.');
        end

        dseq0_plain = decrypt_channel(cseq0_extracted, chao0_stream_dec(1:num_pixels_per_seq_dec), L_value);
        dseq1_plain = decrypt_channel(cseq1_extracted, chao1_stream_dec(1:num_pixels_per_seq_dec), L_value);
        dseq2_plain = decrypt_channel(cseq2_extracted, chao2_stream_dec(1:num_pixels_per_seq_dec), L_value);
        fprintf('Decryption of channels complete.\n');

        % 3. Restore pixels in ROI
        fprintf('3. Restoring plain pixels back to image ROIs...\n');
        plain_image_decrypted = image_to_decrypt; % Start with the encrypted image content

        pixel_restore_count = 0;
        for k_patch_shuffled_res = 1:length(index_seg_shuffled_dec)
            current_patch_original_index_res = index_seg_shuffled_dec(k_patch_shuffled_res);
             info_entry_res = [];
             for r_info_idx = 1:length(ROI_info_dec) % Use ROI_info_dec
                if ROI_info_dec(r_info_idx).patch_index == current_patch_original_index_res
                    info_entry_res = ROI_info_dec(r_info_idx);
                    break;
                end
            end

            if isempty(info_entry_res) || ~info_entry_res.has_roi || isempty(info_entry_res.roi_rect)
                continue;
            end

            rect_res = info_entry_res.roi_rect;
            min_col_res = rect_res(1); min_row_res = rect_res(2);
            max_col_res = rect_res(1) + rect_res(3) - 1;
            max_row_res = rect_res(2) + rect_res(4) - 1;

            for r_idx_res = min_row_res:max_row_res
                for c_idx_res = min_col_res:max_col_res
                    pixel_restore_count = pixel_restore_count + 1;
                    if pixel_restore_count > total_roi_pixels_dec
                         error('Pixel restore count exceeds total ROI pixels during decryption write-back.');
                    end

                    val_ds0 = dseq0_plain(pixel_restore_count);
                    val_ds1 = dseq1_plain(pixel_restore_count);
                    val_ds2 = dseq2_plain(pixel_restore_count);

                    current_rule_idx_res = mod(pixel_restore_count-1, num_rules_dec) +1;
                    rule_res = grouping_rules_dec_extract(current_rule_idx_res); % Rule used during original grouping

                    % Apply Table 4 (Pixel allocation rule in decryption stage)
                    % This means, given dseq values (which are permuted R,G,B), map them back to R,G,B
                    if rule_res == 0 % dseq0 was R, dseq1 was G, dseq2 was B
                        plain_image_decrypted(r_idx_res, c_idx_res, 1) = val_ds0; % R
                        plain_image_decrypted(r_idx_res, c_idx_res, 2) = val_ds1; % G
                        plain_image_decrypted(r_idx_res, c_idx_res, 3) = val_ds2; % B
                    elseif rule_res == 1 % dseq0 was R, dseq1 was B, dseq2 was G
                        plain_image_decrypted(r_idx_res, c_idx_res, 1) = val_ds0; % R
                        plain_image_decrypted(r_idx_res, c_idx_res, 2) = val_ds2; % G
                        plain_image_decrypted(r_idx_res, c_idx_res, 3) = val_ds1; % B
                    elseif rule_res == 2 % dseq0 was G, dseq1 was R, dseq2 was B
                        plain_image_decrypted(r_idx_res, c_idx_res, 1) = val_ds1; % R
                        plain_image_decrypted(r_idx_res, c_idx_res, 2) = val_ds0; % G
                        plain_image_decrypted(r_idx_res, c_idx_res, 3) = val_ds2; % B
                    elseif rule_res == 3 % dseq0 was G, dseq1 was B, dseq2 was R
                        plain_image_decrypted(r_idx_res, c_idx_res, 1) = val_ds2; % R
                        plain_image_decrypted(r_idx_res, c_idx_res, 2) = val_ds0; % G
                        plain_image_decrypted(r_idx_res, c_idx_res, 3) = val_ds1; % B
                    elseif rule_res == 4 % dseq0 was B, dseq1 was R, dseq2 was G
                        plain_image_decrypted(r_idx_res, c_idx_res, 1) = val_ds1; % R
                        plain_image_decrypted(r_idx_res, c_idx_res, 2) = val_ds2; % G
                        plain_image_decrypted(r_idx_res, c_idx_res, 3) = val_ds0; % B
                    elseif rule_res == 5 % dseq0 was B, dseq1 was G, dseq2 was R
                        plain_image_decrypted(r_idx_res, c_idx_res, 1) = val_ds2; % R
                        plain_image_decrypted(r_idx_res, c_idx_res, 2) = val_ds1; % G
                        plain_image_decrypted(r_idx_res, c_idx_res, 3) = val_ds0; % B
                    end
                end
            end
        end
        fprintf('Decryption complete. Plain image ROIs restored.\n');

        % Compare with original if available
        if exist('plain_image_for_decryption','var') && ~isempty(plain_image_for_decryption)
            diff_img = plain_image_for_decryption - plain_image_decrypted;
            if sum(abs(diff_img(:))) == 0
                fprintf('SUCCESS: Decrypted image matches the original plain image.\n');
            else
                fprintf('WARNING: Decrypted image differs from the original plain image.\n');
                % Calculate PSNR or other metrics if desired
                psnr_val = psnr(plain_image_decrypted, plain_image_for_decryption);
                fprintf('PSNR between original and decrypted: %.2f dB\n', psnr_val);
            end
        end

    end % End of decryption block

end

% --- Helper function for encrypting one channel (Alg. 3) ---
function cseq_j = encrypt_channel(seq_j, chao_j_stream, L)
    len_seq = length(seq_j);
    cseq_j = zeros(1, len_seq, 'uint8');

    % Generate permutation indices (Alg.3 lines 3-6)
    perm_indices = 1:len_seq; % 1-based index
    for i = 1:len_seq
        % chaoval calculation needs care to match paper's intent (int64)(|chao_j[i]|*10^15)%(len(seq_j)-i)
        % This creates an index from 0 to len(seq_j)-i-1.
        % For Matlab, we want 1 to len_seq-i+1.
        % A simpler way to get a random index for swapping:
        rand_idx_val = floor(abs(chao_j_stream(i)) * 1e10); % Large number to get varied low bits
        swap_idx_local = mod(rand_idx_val, (len_seq - i + 1)) + 1; % Index in the remaining part of array

        % Convert local swap_idx to global index in perm_indices for the unsorted part
        % The paper swaps index[chaoval] with index[len-1-i]. This is Fisher-Yates like.
        % Let's use Matlab's randperm for a robust permutation based on chaotic sequence as seed,
        % or implement Fisher-Yates properly.
        % For now, a simpler permutation: sort chaotic sequence to get indices
    end
    [~, perm_indices_sorted] = sort(chao_j_stream(1:len_seq)); % Use chaotic values to sort indices
    % perm_indices_final = perm_indices_sorted; % This is one type of permutation

    % Implementing paper's permutation more directly (Alg.3 lines 3-6)
    % This creates permutation `index` in the paper, which is `perm_indices_final` here.
    index_alg3 = 1:len_seq;
    for i = 1:len_seq
        % chaoval is an index from 0 to (len_seq - 1 - (i-1)) = len_seq - i
        % For 1-based index: 1 to len_seq - i + 1
        chaoval_raw = abs(chao_j_stream(i)) * 1e14; % Get some digits
        chaoval_idx = mod(floor(chaoval_raw), (len_seq - (i-1))) + 1; % 1-based index into remaining part

        % Swap index_alg3(chaoval_idx) with index_alg3(len_seq - (i-1))
        % This is a bit confusing. Let's use the standard Fisher-Yates:
    end
    % Standard Fisher-Yates shuffle using chao_j_stream for random numbers
    perm_indices_final = 1:len_seq;
    for i = len_seq:-1:2
        % Generate j from chao_j_stream(len_seq - i + 1) such that 1 <= j <= i
        rand_val_for_swap = abs(chao_j_stream(len_seq - i + 2)); % Use different chaotic number for each swap
        j = mod(floor(rand_val_for_swap * 1e10), i) + 1;

        temp_idx = perm_indices_final(i);
        perm_indices_final(i) = perm_indices_final(j);
        perm_indices_final(j) = temp_idx;
    end
    % perm_indices_final now holds the permutation order for seq_j.
    % seq_j_permuted = seq_j(perm_indices_final); % This is seq_j[index[i]] effectively

    % Diffusion (Alg.3 lines 7-13)
    % preVal = mod(floor(abs(chao_j_stream(2)) * 1e15), L); % Paper uses chao_j[1] (0-indexed)
    % ksele  = mod(floor(abs(chao_j_stream(1)) * 1e15), L); % Paper uses chao_j[0] (0-indexed)
    % For 1-based indexing of chao_j_stream:
    if len_seq == 0, return; end % Handle empty sequence

    preVal = mod(floor(abs(chao_j_stream(min(2, len_seq))) * 1e14), L); % Use 1st if len_seq=1
    ksele_0 = mod(floor(abs(chao_j_stream(1)) * 1e14), L);

    % cseq_j[0] = ksele XOR [(seq_j[index[0]] + ksele)%L] XOR preVal
    term1 = ksele_0;
    term2 = mod(double(seq_j(perm_indices_final(1))) + ksele_0, L);
    term3 = preVal;
    cseq_j(1) = bitxor(uint8(term1), bitxor(uint8(term2), uint8(term3)));

    for i = 2:len_seq
        ksele_i = mod(floor(abs(chao_j_stream(i)) * 1e14), L);
        % cseq_j[i] = ksele XOR [(seq_j[index[i]] + ksele)%L] XOR cseq_j[i-1]
        term1_i = ksele_i;
        term2_i = mod(double(seq_j(perm_indices_final(i))) + ksele_i, L);
        term3_i = cseq_j(i-1); % Previous cipher pixel
        cseq_j(i) = bitxor(uint8(term1_i), bitxor(uint8(term2_i), uint8(term3_i)));
    end
end

% --- Helper function for decrypting one channel (Inverse of Alg. 3) ---
function dseq_j = decrypt_channel(cseq_j, chao_j_stream, L)
    len_seq = length(cseq_j);
    dseq_j_permuted = zeros(1, len_seq, 'uint8'); % This will store plain values but in permuted order

    if len_seq == 0, return; end

    % Diffusion inverse (Alg.3 lines 7-13, reversed)
    preVal = mod(floor(abs(chao_j_stream(min(2,len_seq))) * 1e14), L);
    ksele_0 = mod(floor(abs(chao_j_stream(1)) * 1e14), L);

    % To reverse: P = (C XOR PrevC XOR K) - K mod L
    % For cseq_j[0]: P[index[0]] = (cseq_j[0] XOR preVal XOR ksele_0) - ksele_0 mod L
    val_xor_0 = bitxor(uint8(cseq_j(1)), bitxor(uint8(preVal), uint8(ksele_0)));
    dseq_j_permuted(1) = mod(double(val_xor_0) - ksele_0 + L, L); % Add L before mod for negative results

    for i = 2:len_seq
        ksele_i = mod(floor(abs(chao_j_stream(i)) * 1e14), L);
        % P[index[i]] = (cseq_j[i] XOR cseq_j[i-1] XOR ksele_i) - ksele_i mod L
        val_xor_i = bitxor(uint8(cseq_j(i)), bitxor(uint8(cseq_j(i-1)), uint8(ksele_i)));
        dseq_j_permuted(i) = mod(double(val_xor_i) - ksele_i + L, L);
    end

    % Inverse permutation (Alg.3 lines 3-6, reversed)
    % Generate the same permutation indices as in encryption
    perm_indices_final = 1:len_seq;
    for i = len_seq:-1:2
        rand_val_for_swap = abs(chao_j_stream(len_seq - i + 2));
        j = mod(floor(rand_val_for_swap * 1e10), i) + 1;
        temp_idx = perm_indices_final(i);
        perm_indices_final(i) = perm_indices_final(j);
        perm_indices_final(j) = temp_idx;
    end

    % To reverse permutation: if P_perm = P(perm_idx), then P = P_perm(inv_perm_idx)
    dseq_j = zeros(1, len_seq, 'uint8');
    for i = 1:len_seq
        dseq_j(perm_indices_final(i)) = dseq_j_permuted(i);
    end
end


% % Example Usage (Illustrative - needs actual image and correct paths)
% if 0 % Set to 1 to run example
%     clc; clearvars; close all;
%
%     % Ensure dependent function paths are correct if running this example directly
%     if ~isdeployed
%         addpath(fullfile(pwd, '..', 'chaos_systems'));
%         addpath(fullfile(pwd, '..', 'roi_detection'));
%     end
%
%     % --- Define parameters for the test ---
%     % test_image_name = 'peppers.png'; % Standard Matlab image
%     % Create a small dummy image if peppers.png is not available
%     if exist('peppers.png', 'file')
%         test_image_name = 'peppers.png';
%         try
%             img_test_size_check = imread(test_image_name);
%             if size(img_test_size_check,1) < 50 % If it's too small, use a dummy
%                 error('Test image too small.');
%             end
%         catch
%            fprintf('peppers.png found but seems invalid or too small. Using dummy image.\n');
%            dummy_rgb = uint8(zeros(64,64,3));
%            dummy_rgb(10:30, 10:30, 1) = 255; dummy_rgb(10:30, 10:30, 2) = 128;
%            imwrite(dummy_rgb, 'dummy_rgb_test.png');
%            test_image_name = 'dummy_rgb_test.png';
%         end
%     else
%         fprintf('peppers.png not found. Creating a dummy RGB image.\n');
%         dummy_rgb = uint8(zeros(64,64,3));
%         dummy_rgb(10:30, 10:30, 1) = 255; dummy_rgb(10:30, 10:30, 2) = 128; % Some ROI
%         imwrite(dummy_rgb, 'dummy_rgb_test.png');
%         test_image_name = 'dummy_rgb_test.png';
%     end
%
%     test_N_psrd = 4; % e.g., 4x4 patches
%     test_saliency_method = 'SR'; % Spectral Residual
%     test_saliency_threshold = 'auto';
%
%     test_chaos_params.licc_x0 = 0.3; test_chaos_params.licc_y0 = 1.5; test_chaos_params.licc_z0 = 0.9;
%     test_chaos_params.licc_a = 3.9; test_chaos_params.licc_b = pi; test_chaos_params.licc_c = pi;
%     test_chaos_params.logistic_lambda_grouping = 4.0;
%     test_chaos_params.logistic_x0_grouping = 0.5;
%     test_chaos_params.logistic_lambda_shuffling = 3.95; % Slightly different for shuffling
%     test_chaos_params.logistic_x0_shuffling = 0.55;
%     test_chaos_params.T_discard = 200; % Smaller for faster test run
%
%     % --- Run Encryption and Decryption ---
%     [enc_img, dec_img] = parallel_encrypt_decrypt(test_image_name, ...
%                                         test_N_psrd, ...
%                                         test_saliency_method, ...
%                                         test_saliency_threshold, ...
%                                         test_chaos_params, ...
%                                         true, ... % Perform encryption
%                                         true);   % Perform decryption
%
%     % --- Display Results ---
%     if ~isempty(enc_img) && ~isempty(dec_img)
%         original_img = imread(test_image_name);
%         figure('Name', 'Encryption/Decryption Test');
%         subplot(1,3,1); imshow(original_img); title('Original Image');
%         subplot(1,3,2); imshow(enc_img); title('Encrypted ROI Image');
%         subplot(1,3,3); imshow(dec_img); title('Decrypted Image');
%
%         % PSNR between original and decrypted
%         psnr_val = psnr(dec_img, original_img);
%         fprintf('PSNR between original and final decrypted image: %.2f dB\n', psnr_val);
%         if psnr_val > 35 % Arbitrary threshold for "good" decryption
%             fprintf('Decryption appears successful.\n');
%         else
%             fprintf('Decryption may have issues or image is heavily textured.\n');
%         end
%     else
%         fprintf('Encryption or decryption failed to produce an image.\n');
%     end
%
%     if strcmp(test_image_name,'dummy_rgb_test.png')
%         delete(test_image_name); % Clean up
%     end
% end
