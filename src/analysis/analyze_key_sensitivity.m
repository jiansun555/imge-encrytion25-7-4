function analyze_key_sensitivity(image_path, N_psrd_val, saliency_method, saliency_thresh, base_chaos_params, output_folder, base_filename)
% analyze_key_sensitivity: Performs key sensitivity analysis.
%   - Encryption Sensitivity: Encrypts with Key K1, then with slightly modified Key K2.
%                             Calculates NPCR/UACI between the two cipher ROIs.
%   - Decryption Sensitivity: Encrypts with K1, then decrypts with K1 and K2.
%                             Compares decrypted images (e.g., PSNR, visual).
%
% Args:
%   image_path (str): Path to the original image.
%   N_psrd_val, saliency_method, saliency_thresh: Parameters for ROI detection.
%   base_chaos_params (struct): The original set of chaos parameters (Key K1).
%   output_folder (str): Folder to save output images/plots.
%   base_filename (str): Base name for saved files.
%
% Note: This function relies on the main encryption/decryption pipeline logic.
%       It will call a simplified version of that pipeline.
%       The full `main_encryption_system` is complex to call repeatedly with minor changes.
%       A more modular encryption function `perform_roi_encryption` would be better.
%       For now, it will re-implement parts of the encryption logic.

    fprintf('--- Starting Key Sensitivity Analysis for: %s ---\n', image_path);
    if ~exist(output_folder, 'dir'), mkdir(output_folder); end

    delta = 1e-10; % Small change for key sensitivity

    % --- Load original image ---
    try
        img_orig_uint8 = imread(image_path);
    catch ME
        error('Failed to load image for key sensitivity: %s. Error: %s', image_path, ME.message);
    end

    % --- 1. ROI Detection (once for all tests) ---
    fprintf('Performing ROI detection...\n');
    s_map_bin = detect_saliency(image_path, saliency_method, saliency_thresh);
    ROI_info_ks = psrd(s_map_bin, N_psrd_val);

    % --- Encryption Sensitivity ---
    fprintf('\n--- Testing Encryption Key Sensitivity ---\n');

    % Key K1 (base parameters)
    params_K1 = base_chaos_params;

    % Key K2 (slightly modified LICC initial condition x0)
    params_K2 = base_chaos_params;
    params_K2.licc_x0 = base_chaos_params.licc_x0 + delta;
    % Can also modify other params like logistic_x0, licc_a, etc. one by one.

    fprintf('Encrypting with Key K1 (LICC x0 = %.15f)...\n', params_K1.licc_x0);
    cipher_img_K1 = encrypt_image_roi_for_analysis(img_orig_uint8, ROI_info_ks, N_psrd_val, params_K1);

    fprintf('Encrypting with Key K2 (LICC x0 = %.15f)...\n', params_K2.licc_x0);
    cipher_img_K2 = encrypt_image_roi_for_analysis(img_orig_uint8, ROI_info_ks, N_psrd_val, params_K2);

    if isempty(cipher_img_K1) || isempty(cipher_img_K2)
        fprintf('Encryption failed for K1 or K2. Skipping NPCR/UACI for encryption sensitivity.\n');
    else
        % Extract ROI pixels from cipher_img_K1 and cipher_img_K2
        % Need the shuffled patch order used during their encryption
        % This means encrypt_image_roi_for_analysis needs to return it or be consistent.
        % For NPCR/UACI, we compare the 1D streams of ROI pixels.

        % To get the 1D streams, we need to call extract_pixels again on cipher images,
        % but this is not quite right. We need the *effective* 1D stream of *ciphered values*
        % in the order they were encrypted.
        % The simplest is to get all ROI pixels from cipher_img_K1 and cipher_img_K2
        % using a consistent helper. Let's use the one from analyze_histogram.m
        % (The patch order for extraction doesn't matter for NPCR/UACI as long as it's consistent for both images).

        % Generate a dummy index_seg_shuffled for get_roi_pixels_from_image, assuming scanline order for this analysis part.
        % This is okay if we just need a consistent way to linearize ROI pixels from the 2D encrypted images.
        dummy_patch_order = 1:(N_psrd_val*N_psrd_val);

        roi_pixels_C1_cell = get_roi_pixels_from_image_for_analysis(cipher_img_K1, ROI_info_ks, dummy_patch_order);
        roi_pixels_C2_cell = get_roi_pixels_from_image_for_analysis(cipher_img_K2, ROI_info_ks, dummy_patch_order);

        if ~isempty(roi_pixels_C1_cell{1}) && ~isempty(roi_pixels_C2_cell{1})
            % Combine channels for overall NPCR/UACI or analyze per channel
            C1_combined = [roi_pixels_C1_cell{1}, roi_pixels_C1_cell{2}, roi_pixels_C1_cell{3}];
            C2_combined = [roi_pixels_C2_cell{1}, roi_pixels_C2_cell{2}, roi_pixels_C2_cell{3}];

            if length(C1_combined) == length(C2_combined) && ~isempty(C1_combined)
                [npcr_enc_sens, uaci_enc_sens] = calculate_npcr_uaci(C1_combined, C2_combined, 255);
                fprintf('Encryption Sensitivity (K1 vs K2):\n');
                fprintf('  NPCR: %.4f%%\n', npcr_enc_sens * 100);
                fprintf('  UACI: %.4f%%\n', uaci_enc_sens * 100);

                h_fig_enc_sens = figure('Name', 'Encryption Sensitivity Cipher Images', 'Visible', 'off');
                subplot(1,2,1); imshow(cipher_img_K1); title('Cipher ROI (K1)');
                subplot(1,2,2); imshow(cipher_img_K2); title('Cipher ROI (K2)');
                sgtitle(sprintf('Enc. Sensitivity: NPCR=%.2f%%, UACI=%.2f%%', npcr_enc_sens*100, uaci_enc_sens*100));
                try
                    saveas(h_fig_enc_sens, fullfile(output_folder, [base_filename, '_enc_sensitivity_images.png']));
                catch ME_save1
                    fprintf('Could not save enc sensitivity image: %s\n', ME_save1.message);
                end
                close(h_fig_enc_sens);
            else
                fprintf('Mismatch in ROI pixel counts or empty ROIs for K1/K2 ciphers. Cannot compute NPCR/UACI.\n');
            end
        else
            fprintf('Failed to extract ROI pixels from K1 or K2 ciphers.\n');
        end
    end

    % --- Decryption Sensitivity ---
    fprintf('\n--- Testing Decryption Key Sensitivity ---\n');
    % Encrypt with K1 (already done: cipher_img_K1)
    if isempty(cipher_img_K1)
        fprintf('Cipher image with K1 not available. Skipping decryption sensitivity.\n');
    else
        fprintf('Decrypting Cipher (K1) with Key K1...\n');
        decrypted_img_K1_K1 = decrypt_image_roi_for_analysis(cipher_img_K1, ROI_info_ks, N_psrd_val, params_K1);

        fprintf('Decrypting Cipher (K1) with Key K2 (modified key)...\n');
        decrypted_img_K1_K2 = decrypt_image_roi_for_analysis(cipher_img_K1, ROI_info_ks, N_psrd_val, params_K2);

        if isempty(decrypted_img_K1_K1) || isempty(decrypted_img_K1_K2)
            fprintf('Decryption failed for K1 or K2. Skipping decryption sensitivity comparison.\n');
        else
            psnr_val = psnr(decrypted_img_K1_K1, img_orig_uint8);
            fprintf('  PSNR (Original vs Decrypted with K1): %.2f dB\n', psnr_val);

            % Compare decrypted_img_K1_K1 and decrypted_img_K1_K2
            % Visually, and also NPCR/UACI between these two decrypted images.
            roi_pixels_D_K1K1 = get_roi_pixels_from_image_for_analysis(decrypted_img_K1_K1, ROI_info_ks, dummy_patch_order);
            roi_pixels_D_K1K2 = get_roi_pixels_from_image_for_analysis(decrypted_img_K1_K2, ROI_info_ks, dummy_patch_order);

            D_K1K1_comb = [roi_pixels_D_K1K1{1}, roi_pixels_D_K1K1{2}, roi_pixels_D_K1K1{3}];
            D_K1K2_comb = [roi_pixels_D_K1K2{1}, roi_pixels_D_K1K2{2}, roi_pixels_D_K1K2{3}];

            if length(D_K1K1_comb) == length(D_K1K2_comb) && ~isempty(D_K1K1_comb)
                [npcr_dec_sens, uaci_dec_sens] = calculate_npcr_uaci(D_K1K1_comb, D_K1K2_comb, 255);
                fprintf('Decryption Sensitivity (Correct Key vs Wrong Key on same Ciphertext):\n');
                fprintf('  NPCR between Dec(K1) and Dec(K2): %.4f%%\n', npcr_dec_sens * 100);
                fprintf('  UACI between Dec(K1) and Dec(K2): %.4f%%\n', uaci_dec_sens * 100);
            end

            h_fig_dec_sens = figure('Name', 'Decryption Sensitivity Images', 'Visible', 'off');
            subplot(1,3,1); imshow(img_orig_uint8); title('Original Plaintext');
            subplot(1,3,2); imshow(decrypted_img_K1_K1); title('Decrypted with K1 (Correct)');
            subplot(1,3,3); imshow(decrypted_img_K1_K2); title('Decrypted with K2 (Wrong)');
            sgtitle(sprintf('Dec. Sensitivity: PSNR(Orig,Dec(K1))=%.1fdB. NPCR(DecK1,DecK2)=%.1f%%',psnr_val, npcr_dec_sens*100));
            try
                saveas(h_fig_dec_sens, fullfile(output_folder, [base_filename, '_dec_sensitivity_images.png']));
            catch ME_save2
                 fprintf('Could not save dec sensitivity image: %s\n', ME_save2.message);
            end
            close(h_fig_dec_sens);
        end
    end
    fprintf('\nKey Sensitivity Analysis Complete. Plots saved to folder: %s\n', output_folder);
end


% --- Helper: Simplified Encryption for Analysis ---
function cipher_img = encrypt_image_roi_for_analysis(plain_img, ROI_info, N, chaos_params_enc)
    % Extracts pixels, encrypts channels, writes back to image.
    % This is a condensed version of the main encryption flow.

    [seq0_p, seq1_p, seq2_p, idx_seg_shuff, total_pix] = ...
        extract_pixels(plain_img, ROI_info, N, chaos_params_enc);

    if total_pix == 0, cipher_img = plain_img; return; end

    num_pix_seq = total_pix;
    [ch_x, ch_y, ch_z] = licc_system(chaos_params_enc.licc_x0, chaos_params_enc.licc_y0, chaos_params_enc.licc_z0, ...
                                     chaos_params_enc.licc_a, chaos_params_enc.licc_b, chaos_params_enc.licc_c, ...
                                     num_pix_seq, chaos_params_enc.T_discard);
    if length(ch_x) < num_pix_seq, error('LICC failed (enc for analysis)'); end

    cseq0 = encrypt_channel(seq0_p, ch_x(1:num_pix_seq), 256);
    cseq1 = encrypt_channel(seq1_p, ch_y(1:num_pix_seq), 256);
    cseq2 = encrypt_channel(seq2_p, ch_z(1:num_pix_seq), 256);

    cipher_img = plain_img; % Start with copy
    num_rules_enc_an = floor(total_pix / 3);
    chaoseq_logi_enc_an = logistic_map(chaos_params_enc.logistic_x0_grouping, ...
                                chaos_params_enc.logistic_lambda_grouping, ...
                                num_rules_enc_an, chaos_params_enc.T_discard);
    grouping_rules_enc_an = mod(floor(abs(chaoseq_logi_enc_an) * 6), 6);

    pix_write_cnt = 0;
    for k_p = 1:length(idx_seg_shuff)
        curr_p_idx = idx_seg_shuff(k_p);
        info_e = ROI_info(curr_p_idx); % Assuming ROI_info is 1 to N*N indexed

        if ~info_e.has_roi || isempty(info_e.roi_rect), continue; end
        rect_e = info_e.roi_rect;
        for r_e = rect_e(2) : (rect_e(2)+rect_e(4)-1)
            for c_e = rect_e(1) : (rect_e(1)+rect_e(3)-1)
                pix_write_cnt = pix_write_cnt + 1;
                val_s0, val_s1, val_s2 = cseq0(pix_write_cnt), cseq1(pix_write_cnt), cseq2(pix_write_cnt);
                rule_e = grouping_rules_enc_an(mod(pix_write_cnt-1, num_rules_enc_an)+1);
                % Write back logic (same as in main_encryption_system)
                if rule_e == 0, cipher_img(r_e,c_e,:)=reshape([val_s0,val_s1,val_s2],1,1,3);
                elseif rule_e == 1, cipher_img(r_e,c_e,:)=reshape([val_s0,val_s2,val_s1],1,1,3);
                elseif rule_e == 2, cipher_img(r_e,c_e,:)=reshape([val_s1,val_s0,val_s2],1,1,3);
                elseif rule_e == 3, cipher_img(r_e,c_e,:)=reshape([val_s2,val_s0,val_s1],1,1,3);
                elseif rule_e == 4, cipher_img(r_e,c_e,:)=reshape([val_s1,val_s2,val_s0],1,1,3);
                elseif rule_e == 5, cipher_img(r_e,c_e,:)=reshape([val_s2,val_s1,val_s0],1,1,3);
                end
            end
        end
    end
end

% --- Helper: Simplified Decryption for Analysis ---
function plain_img_out = decrypt_image_roi_for_analysis(cipher_img_in, ROI_info, N, chaos_params_dec)
    % Extracts ciphered ROI pixels, decrypts channels, writes back.
    num_rules_dec_an = 0; % Will be set after total_pix_dec is known
    total_pix_dec = 0;
     for k_roi_count = 1:length(ROI_info) % Calculate total_pix_dec
        if ROI_info(k_roi_count).has_roi && ~isempty(ROI_info(k_roi_count).roi_rect)
            rect_count = ROI_info(k_roi_count).roi_rect;
            total_pix_dec = total_pix_dec + rect_count(3)*rect_count(4);
        end
    end
    if total_pix_dec == 0, plain_img_out = cipher_img_in; return; end

    num_rules_dec_an = floor(total_pix_dec / 3);
    chaoseq_logi_dec_an_grp = logistic_map(chaos_params_dec.logistic_x0_grouping, ...
                                chaos_params_dec.logistic_lambda_grouping, ...
                                num_rules_dec_an, chaos_params_dec.T_discard);
    grouping_rules_dec_an_ext = mod(floor(abs(chaoseq_logi_dec_an_grp) * 6),6);

    % Regenerate shuffled patch order (must match encryption)
    num_patches_dec_an = N*N; patch_idx_dec_an = 1:num_patches_dec_an;
    shuffle_chaos_dec_an = logistic_map(chaos_params_dec.logistic_x0_shuffling, ...
                                 chaos_params_dec.logistic_lambda_shuffling, ...
                                 num_patches_dec_an, chaos_params_dec.T_discard);
    [~, sorted_shuffle_idx_dec_an] = sort(shuffle_chaos_dec_an);
    idx_seg_shuff_dec = patch_idx_dec_an(sorted_shuffle_idx_dec_an);

    cseq0_ext, cseq1_ext, cseq2_ext = deal(zeros(1,total_pix_dec,'uint8'));
    pix_ext_cnt_dec = 0;
    for k_p_dec = 1:length(idx_seg_shuff_dec)
        curr_p_idx_dec = idx_seg_shuff_dec(k_p_dec);
        info_e_dec = ROI_info(curr_p_idx_dec);
        if ~info_e_dec.has_roi || isempty(info_e_dec.roi_rect), continue; end
        rect_e_dec = info_e_dec.roi_rect;
        for r_ed = rect_e_dec(2):(rect_e_dec(2)+rect_e_dec(4)-1)
            for c_ed = rect_e_dec(1):(rect_e_dec(1)+rect_e_dec(3)-1)
                pix_ext_cnt_dec = pix_ext_cnt_dec + 1;
                img_R_d, img_G_d, img_B_d = cipher_img_in(r_ed,c_ed,1), cipher_img_in(r_ed,c_ed,2), cipher_img_in(r_ed,c_ed,3);
                rule_d = grouping_rules_dec_an_ext(mod(pix_ext_cnt_dec-1, num_rules_dec_an)+1);
                % Extraction logic (same as in main_encryption_system decryption)
                if rule_d==0,cseq0_ext(pix_ext_cnt_dec)=img_R_d; cseq1_ext(pix_ext_cnt_dec)=img_G_d; cseq2_ext(pix_ext_cnt_dec)=img_B_d;
                elseif rule_d==1,cseq0_ext(pix_ext_cnt_dec)=img_R_d; cseq1_ext(pix_ext_cnt_dec)=img_B_d; cseq2_ext(pix_ext_cnt_dec)=img_G_d;
                elseif rule_d==2,cseq0_ext(pix_ext_cnt_dec)=img_G_d; cseq1_ext(pix_ext_cnt_dec)=img_R_d; cseq2_ext(pix_ext_cnt_dec)=img_B_d;
                elseif rule_d==3,cseq0_ext(pix_ext_cnt_dec)=img_G_d; cseq1_ext(pix_ext_cnt_dec)=img_B_d; cseq2_ext(pix_ext_cnt_dec)=img_R_d;
                elseif rule_d==4,cseq0_ext(pix_ext_cnt_dec)=img_B_d; cseq1_ext(pix_ext_cnt_dec)=img_R_d; cseq2_ext(pix_ext_cnt_dec)=img_G_d;
                elseif rule_d==5,cseq0_ext(pix_ext_cnt_dec)=img_B_d; cseq1_ext(pix_ext_cnt_dec)=img_G_d; cseq2_ext(pix_ext_cnt_dec)=img_R_d;
                end
            end
        end
    end

    [ch_x_d, ch_y_d, ch_z_d] = licc_system(chaos_params_dec.licc_x0, chaos_params_dec.licc_y0, chaos_params_dec.licc_z0, ...
                                     chaos_params_dec.licc_a, chaos_params_dec.licc_b, chaos_params_dec.licc_c, ...
                                     total_pix_dec, chaos_params_dec.T_discard);
    if length(ch_x_d) < total_pix_dec, error('LICC failed (dec for analysis)'); end

    dseq0 = decrypt_channel(cseq0_ext, ch_x_d(1:total_pix_dec), 256);
    dseq1 = decrypt_channel(cseq1_ext, ch_y_d(1:total_pix_dec), 256);
    dseq2 = decrypt_channel(cseq2_ext, ch_z_d(1:total_pix_dec), 256);

    plain_img_out = cipher_img_in; % Start with copy
    pix_restore_cnt = 0;
    for k_p_res = 1:length(idx_seg_shuff_dec)
        curr_p_idx_res = idx_seg_shuff_dec(k_p_res);
        info_e_res = ROI_info(curr_p_idx_res);
        if ~info_e_res.has_roi || isempty(info_e_res.roi_rect), continue; end
        rect_e_res = info_e_res.roi_rect;
        for r_er = rect_e_res(2):(rect_e_res(2)+rect_e_res(4)-1)
            for c_er = rect_e_res(1):(rect_e_res(1)+rect_e_res(3)-1)
                pix_restore_cnt = pix_restore_cnt + 1;
                val_ds0, val_ds1, val_ds2 = dseq0(pix_restore_cnt),dseq1(pix_restore_cnt),dseq2(pix_restore_cnt);
                rule_r = grouping_rules_dec_an_ext(mod(pix_restore_cnt-1, num_rules_dec_an)+1);
                % Restore logic (Table 4, same as in main_encryption_system)
                if rule_r==0,plain_img_out(r_er,c_er,:)=reshape([val_ds0,val_ds1,val_ds2],1,1,3);
                elseif rule_r==1,plain_img_out(r_er,c_er,:)=reshape([val_ds0,val_ds2,val_ds1],1,1,3);
                elseif rule_r==2,plain_img_out(r_er,c_er,:)=reshape([val_ds1,val_ds0,val_ds2],1,1,3);
                elseif rule_r==3,plain_img_out(r_er,c_er,:)=reshape([val_ds2,val_ds0,val_ds1],1,1,3);
                elseif rule_r==4,plain_img_out(r_er,c_er,:)=reshape([val_ds1,val_ds2,val_ds0],1,1,3);
                elseif rule_r==5,plain_img_out(r_er,c_er,:)=reshape([val_ds2,val_ds1,val_ds0],1,1,3);
                end
            end
        end
    end
end

% --- NPCR/UACI Calculation --- (Should be in a separate utility file ideally)
function [npcr, uaci] = calculate_npcr_uaci(img1_roi_flat, img2_roi_flat, max_pixel_val)
    if length(img1_roi_flat) ~= length(img2_roi_flat) || isempty(img1_roi_flat)
        npcr = NaN; uaci = NaN; return;
    end
    L = length(img1_roi_flat);
    num_diff_pixels = sum(img1_roi_flat ~= img2_roi_flat);
    npcr = num_diff_pixels / L;

    uaci_sum = sum(abs(double(img1_roi_flat) - double(img2_roi_flat))) / max_pixel_val;
    uaci = uaci_sum / L;
end

% --- Re-use get_roi_pixels_from_image from analyze_histogram.m ---
% (Copied here for self-containment of this analysis script if run standalone, ensure it's consistent)
function roi_pixels_cell = get_roi_pixels_from_image_for_analysis(image_matrix, ROI_info_struct, index_seg_shuffled_order)
    if isempty(ROI_info_struct) || isempty(image_matrix)
        roi_pixels_cell = {[], [], []}; return;
    end
    total_pixels_in_rois = 0;
    for k_patch = 1:length(ROI_info_struct)
        if ROI_info_struct(k_patch).has_roi && ~isempty(ROI_info_struct(k_patch).roi_rect)
            rect = ROI_info_struct(k_patch).roi_rect;
            total_pixels_in_rois = total_pixels_in_rois + rect(3)*rect(4);
        end
    end
    if total_pixels_in_rois == 0, roi_pixels_cell = {[], [], []}; return; end

    R_all=zeros(1,total_pixels_in_rois,'uint8'); G_all=zeros(1,total_pixels_in_rois,'uint8'); B_all=zeros(1,total_pixels_in_rois,'uint8');
    current_pixel_idx = 0;
    order_to_use = index_seg_shuffled_order;
    if isempty(order_to_use) % Fallback if no order provided
        order_to_use = 1:length(ROI_info_struct);
    end

    for k_shuffled = 1:length(order_to_use)
        patch_original_idx = order_to_use(k_shuffled);
        info_entry = ROI_info_struct(patch_original_idx); % Assuming ROI_info is already 1 to N*N indexed if order_to_use is simple 1:length
        % If index_seg_shuffled_order contains original patch indices, then a search is needed:
        % info_entry = []; for r_idx=1:length(ROI_info_struct) if ROI_info_struct(r_idx).patch_index == patch_original_idx, info_entry=ROI_info_struct(r_idx); break; end; end

        if ~isempty(info_entry) && info_entry.has_roi && ~isempty(info_entry.roi_rect)
            rect = info_entry.roi_rect;
            min_c=rect(1); min_r=rect(2); max_c=rect(1)+rect(3)-1; max_r=rect(2)+rect(4)-1;
            for r = min_r:max_r, for c = min_c:max_c
                current_pixel_idx = current_pixel_idx + 1;
                R_all(current_pixel_idx)=image_matrix(r,c,1); G_all(current_pixel_idx)=image_matrix(r,c,2); B_all(current_pixel_idx)=image_matrix(r,c,3);
            end; end
        end
    end
    roi_pixels_cell = {R_all(1:current_pixel_idx), G_all(1:current_pixel_idx), B_all(1:current_pixel_idx)};
end

% Functions encrypt_channel and decrypt_channel are assumed to be on path
% (e.g., from parallel_encrypt_decrypt.m or main_encryption_system.m)
% If not, they need to be defined here or in a shared utility.
% For this file, I'll copy paste their definitions for completeness if main_encryption_system.m is not used as a library.
% (encrypt_channel and decrypt_channel definitions would go here if needed)

% % Example Usage (requires other functions and an image)
% if 0
%     clc; clearvars; close all;
%     % Setup paths to other modules if not running from a main script that does this
%     addpath(genpath('../../src')); % Assuming this file is in src/analysis
%
%     test_img = 'peppers.png'; % Make sure this image is available
%     if ~exist(test_img, 'file'), error('Test image %s not found.', test_img); end
%
%     key_sens_N = 4;
%     key_sens_saliency_method = 'SR';
%     key_sens_saliency_thresh = 'auto';
%
%     key_sens_base_params.licc_x0 = 0.3; key_sens_base_params.licc_y0 = 1.5; key_sens_base_params.licc_z0 = 0.9;
%     key_sens_base_params.licc_a = 3.9; key_sens_base_params.licc_b = pi; key_sens_base_params.licc_c = pi;
%     key_sens_base_params.logistic_lambda_grouping = 4.0;
%     key_sens_base_params.logistic_x0_grouping = 0.5;
%     key_sens_base_params.logistic_lambda_shuffling = 3.95;
%     key_sens_base_params.logistic_x0_shuffling = 0.55;
%     key_sens_base_params.T_discard = 200; % Faster for test
%
%     key_sens_output_folder = 'temp_results_keysens';
%     key_sens_base_filename = 'peppers_keysens';
%
%     analyze_key_sensitivity(test_img, key_sens_N, key_sens_saliency_method, key_sens_saliency_thresh, ...
%                             key_sens_base_params, key_sens_output_folder, key_sens_base_filename);
%
%     fprintf('Key sensitivity analysis example finished. Check folder %s.\n', key_sens_output_folder);
%     % rmdir(key_sens_output_folder, 's'); % Clean up
% end
