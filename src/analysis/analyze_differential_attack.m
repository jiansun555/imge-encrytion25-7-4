function analyze_differential_attack(image_path, N_psrd_val, saliency_method, saliency_thresh, chaos_params_diff, output_folder, base_filename)
% analyze_differential_attack: Performs differential attack analysis (NPCR/UACI).
%   - Encrypts original image P1 to get C1.
%   - Modifies one pixel in P1 to get P2.
%   - Encrypts P2 with the same key to get C2.
%   - Calculates NPCR/UACI between ROIs of C1 and C2.
%
% Args:
%   image_path (str): Path to the original image.
%   N_psrd_val, saliency_method, saliency_thresh: Parameters for ROI detection.
%   chaos_params_diff (struct): Chaos parameters for encryption.
%   output_folder (str): Folder to save any output images/plots.
%   base_filename (str): Base name for saved files.

    fprintf('--- Starting Differential Attack Analysis for: %s ---\n', image_path);
    if ~exist(output_folder, 'dir'), mkdir(output_folder); end

    % --- Load original image P1 ---
    try
        P1_uint8 = imread(image_path);
        if size(P1_uint8,3) ~= 3, error('Differential attack analysis requires RGB image.'); end
    catch ME
        error('Failed to load image for differential attack: %s. Error: %s', image_path, ME.message);
    end

    % --- ROI Detection (once for P1, assumed same for P2 as only one pixel changes) ---
    fprintf('Performing ROI detection on P1...\n');
    s_map_bin_P1 = detect_saliency(image_path, saliency_method, saliency_thresh);
    ROI_info_diff = psrd(s_map_bin_P1, N_psrd_val);

    % --- Encrypt P1 to get C1 ---
    fprintf('Encrypting original image P1 to get C1...\n');
    C1_img = encrypt_image_roi_for_analysis(P1_uint8, ROI_info_diff, N_psrd_val, chaos_params_diff);
    if isempty(C1_img)
        fprintf('Encryption of P1 failed. Aborting differential analysis.\n');
        return;
    end

    % --- Create P2 by modifying one pixel in P1 ---
    P2_uint8 = P1_uint8;
    % Choose a pixel to modify (e.g., center pixel, or a pixel within an ROI if possible)
    [rows, cols, ~] = size(P2_uint8);
    mod_r = floor(rows/2);
    mod_c = floor(cols/2);
    mod_ch = 1; % Modify Red channel

    original_pixel_val = P2_uint8(mod_r, mod_c, mod_ch);
    modified_pixel_val = mod(double(original_pixel_val) + 1, 256); % Add 1 (wrap around if 255)
    P2_uint8(mod_r, mod_c, mod_ch) = uint8(modified_pixel_val);
    fprintf('Created P2 by changing pixel (%d,%d,%d) from %d to %d.\n', mod_r, mod_c, mod_ch, original_pixel_val, modified_pixel_val);

    % --- Encrypt P2 to get C2 (using same key and ROI_info from P1) ---
    fprintf('Encrypting modified image P2 to get C2...\n');
    C2_img = encrypt_image_roi_for_analysis(P2_uint8, ROI_info_diff, N_psrd_val, chaos_params_diff);
    if isempty(C2_img)
        fprintf('Encryption of P2 failed. Aborting differential analysis.\n');
        return;
    end

    % --- Calculate NPCR and UACI between ROIs of C1 and C2 ---
    % Extract linearized ROI pixels from C1 and C2
    % Use a consistent (e.g. scanline) order for extracting pixels from ROIs of C1 and C2.
    dummy_patch_order_diff = 1:(N_psrd_val*N_psrd_val); % Consistent order for linearization

    roi_pixels_C1_cell_diff = get_roi_pixels_from_image_for_analysis(C1_img, ROI_info_diff, dummy_patch_order_diff);
    roi_pixels_C2_cell_diff = get_roi_pixels_from_image_for_analysis(C2_img, ROI_info_diff, dummy_patch_order_diff);

    if ~isempty(roi_pixels_C1_cell_diff{1}) && ~isempty(roi_pixels_C2_cell_diff{1})
        C1_combined_diff = [roi_pixels_C1_cell_diff{1}, roi_pixels_C1_cell_diff{2}, roi_pixels_C1_cell_diff{3}];
        C2_combined_diff = [roi_pixels_C2_cell_diff{1}, roi_pixels_C2_cell_diff{2}, roi_pixels_C2_cell_diff{3}];

        if length(C1_combined_diff) == length(C2_combined_diff) && ~isempty(C1_combined_diff)
            [npcr_diff, uaci_diff] = calculate_npcr_uaci(C1_combined_diff, C2_combined_diff, 255);
            fprintf('\nDifferential Attack Analysis Results (C1 vs C2 ROIs):\n');
            fprintf('  NPCR: %.4f%%\n', npcr_diff * 100);
            fprintf('  UACI: %.4f%%\n', uaci_diff * 100);

            % Save C1 and C2 images (optional)
            try
                imwrite(C1_img, fullfile(output_folder, [base_filename, '_C1_diff.png']));
                imwrite(C2_img, fullfile(output_folder, [base_filename, '_C2_diff.png']));
            catch ME_save_c1c2
                fprintf('Could not save C1/C2 images: %s\n', ME_save_c1c2.message);
            end

        else
            fprintf('Mismatch in ROI pixel counts or empty ROIs for C1/C2. Cannot compute NPCR/UACI.\n');
        end
    else
        fprintf('Failed to extract ROI pixels from C1 or C2 for differential analysis.\n');
    end

    fprintf('\nDifferential Attack Analysis Complete. Any generated files saved to: %s\n', output_folder);
end


% --- Helper: Simplified Encryption for Analysis (copied from analyze_key_sensitivity.m) ---
% (Ensure this is consistent if it's also in other files or make it a shared utility)
function cipher_img = encrypt_image_roi_for_analysis(plain_img, ROI_info, N, chaos_params_enc)
    [seq0_p, seq1_p, seq2_p, idx_seg_shuff, total_pix] = ...
        extract_pixels(plain_img, ROI_info, N, chaos_params_enc);
    if total_pix == 0, cipher_img = plain_img; fprintf('Warning: No pixels to encrypt in encrypt_image_roi_for_analysis.\n'); return; end

    num_pix_seq = total_pix;
    [ch_x, ch_y, ch_z] = licc_system(chaos_params_enc.licc_x0, chaos_params_enc.licc_y0, chaos_params_enc.licc_z0, ...
                                     chaos_params_enc.licc_a, chaos_params_enc.licc_b, chaos_params_enc.licc_c, ...
                                     num_pix_seq, chaos_params_enc.T_discard);
    if length(ch_x) < num_pix_seq, error('LICC failed (enc for analysis helper)'); end

    cseq0 = encrypt_channel(seq0_p, ch_x(1:num_pix_seq), 256);
    cseq1 = encrypt_channel(seq1_p, ch_y(1:num_pix_seq), 256);
    cseq2 = encrypt_channel(seq2_p, ch_z(1:num_pix_seq), 256);

    cipher_img = plain_img;
    num_rules_enc_an = floor(total_pix / 3);
     if num_rules_enc_an == 0 && total_pix > 0 % Handle case where total_pix < 3
        num_rules_enc_an = 1;
    elseif num_rules_enc_an == 0 && total_pix == 0
        % This case is already handled by total_pix check above, but good to be safe
        return;
    end
    chaoseq_logi_enc_an = logistic_map(chaos_params_enc.logistic_x0_grouping, ...
                                chaos_params_enc.logistic_lambda_grouping, ...
                                num_rules_enc_an, chaos_params_enc.T_discard);
    if isempty(chaoseq_logi_enc_an) && num_rules_enc_an > 0, error('Logistic map failed to generate rules for encryption analysis helper.'); end
    grouping_rules_enc_an = mod(floor(abs(chaoseq_logi_enc_an) * 6), 6);

    pix_write_cnt = 0;
    for k_p = 1:length(idx_seg_shuff)
        curr_p_idx = idx_seg_shuff(k_p);
        % Ensure ROI_info is indexed correctly if it's not dense 1:N*N
        info_entry_idx = find([ROI_info.patch_index] == curr_p_idx, 1);
        if isempty(info_entry_idx), continue; end % Should not happen if idx_seg_shuff is from ROI_info
        info_e = ROI_info(info_entry_idx);

        if ~info_e.has_roi || isempty(info_e.roi_rect), continue; end
        rect_e = info_e.roi_rect;
        for r_e = rect_e(2) : (rect_e(2)+rect_e(4)-1)
            for c_e = rect_e(1) : (rect_e(1)+rect_e(3)-1)
                pix_write_cnt = pix_write_cnt + 1;
                if pix_write_cnt > total_pix, error('Pixel write count exceeded total pixels in analysis encryption.'); end
                val_s0 = cseq0(pix_write_cnt); val_s1 = cseq1(pix_write_cnt); val_s2 = cseq2(pix_write_cnt);
                rule_e = grouping_rules_enc_an(mod(pix_write_cnt-1, num_rules_enc_an)+1);
                if rule_e==0, cipher_img(r_e,c_e,:)=reshape([val_s0,val_s1,val_s2],1,1,3);
                elseif rule_e==1, cipher_img(r_e,c_e,:)=reshape([val_s0,val_s2,val_s1],1,1,3);
                elseif rule_e==2, cipher_img(r_e,c_e,:)=reshape([val_s1,val_s0,val_s2],1,1,3);
                elseif rule_e==3, cipher_img(r_e,c_e,:)=reshape([val_s2,val_s0,val_s1],1,1,3);
                elseif rule_e==4, cipher_img(r_e,c_e,:)=reshape([val_s1,val_s2,val_s0],1,1,3);
                elseif rule_e==5, cipher_img(r_e,c_e,:)=reshape([val_s2,val_s1,val_s0],1,1,3);
                end
            end
        end
    end
end

% --- NPCR/UACI Calculation --- (copied from analyze_key_sensitivity.m)
function [npcr, uaci] = calculate_npcr_uaci(img1_roi_flat, img2_roi_flat, max_pixel_val)
    if length(img1_roi_flat) ~= length(img2_roi_flat) || isempty(img1_roi_flat)
        npcr = NaN; uaci = NaN; fprintf('Warning: NPCR/UACI inputs invalid.\n'); return;
    end
    L = length(img1_roi_flat);
    num_diff_pixels = sum(img1_roi_flat ~= img2_roi_flat);
    npcr = num_diff_pixels / L;

    uaci_sum = sum(abs(double(img1_roi_flat) - double(img2_roi_flat))) / max_pixel_val;
    uaci = uaci_sum / L;
end

% --- Re-use get_roi_pixels_from_image_for_analysis (copied from analyze_key_sensitivity.m) ---
function roi_pixels_cell = get_roi_pixels_from_image_for_analysis(image_matrix, ROI_info_struct, index_seg_shuffled_order)
    if isempty(ROI_info_struct) || isempty(image_matrix)
        roi_pixels_cell = {[], [], []}; return;
    end
    total_pixels_in_rois = 0;
    for k_patch = 1:length(ROI_info_struct)
         % Check if ROI_info_struct(k_patch) is valid and has_roi
        if isfield(ROI_info_struct(k_patch),'has_roi') && ROI_info_struct(k_patch).has_roi && ~isempty(ROI_info_struct(k_patch).roi_rect)
            rect = ROI_info_struct(k_patch).roi_rect;
            total_pixels_in_rois = total_pixels_in_rois + rect(3)*rect(4);
        end
    end
    if total_pixels_in_rois == 0, roi_pixels_cell = {[], [], []}; return; end

    R_all=zeros(1,total_pixels_in_rois,'uint8'); G_all=zeros(1,total_pixels_in_rois,'uint8'); B_all=zeros(1,total_pixels_in_rois,'uint8');
    current_pixel_idx = 0;
    order_to_use = index_seg_shuffled_order;
    if isempty(order_to_use), order_to_use = 1:length(ROI_info_struct); end

    for k_shuffled = 1:length(order_to_use)
        patch_original_idx = order_to_use(k_shuffled);
        info_entry_idx = find([ROI_info_struct.patch_index] == patch_original_idx, 1);
        if isempty(info_entry_idx), continue; end
        info_entry = ROI_info_struct(info_entry_idx);

        if info_entry.has_roi && ~isempty(info_entry.roi_rect)
            rect = info_entry.roi_rect;
            min_c=rect(1); min_r=rect(2); max_c=rect(1)+rect(3)-1; max_r=rect(2)+rect(4)-1;
            for r = min_r:max_r, for c = min_c:max_c
                current_pixel_idx = current_pixel_idx + 1;
                if current_pixel_idx > total_pixels_in_rois, error('Pixel count exceeded in get_roi_pixels (analysis)'); end
                R_all(current_pixel_idx)=image_matrix(r,c,1); G_all(current_pixel_idx)=image_matrix(r,c,2); B_all(current_pixel_idx)=image_matrix(r,c,3);
            end; end
        end
    end
    roi_pixels_cell = {R_all(1:current_pixel_idx), G_all(1:current_pixel_idx), B_all(1:current_pixel_idx)};
end

% Assumed: encrypt_channel, licc_system, logistic_map, extract_pixels, detect_saliency, psrd are on path.

% % Example Usage:
% if 0
%     clc; clearvars; close all;
%     addpath(genpath('../../src'));
%
%     test_img_diff = 'peppers.png';
%     if ~exist(test_img_diff, 'file'), error('Test image %s not found.', test_img_diff); end
%
%     diff_N = 4;
%     diff_saliency_method = 'SR';
%     diff_saliency_thresh = 'auto';
%
%     diff_base_params.licc_x0 = 0.3; diff_base_params.licc_y0 = 1.5; diff_base_params.licc_z0 = 0.9;
%     diff_base_params.licc_a = 3.9; diff_base_params.licc_b = pi; diff_base_params.licc_c = pi;
%     diff_base_params.logistic_lambda_grouping = 4.0;
%     diff_base_params.logistic_x0_grouping = 0.5;
%     diff_base_params.logistic_lambda_shuffling = 3.95;
%     diff_base_params.logistic_x0_shuffling = 0.55;
%     diff_base_params.T_discard = 200;
%
%     diff_output_folder = 'temp_results_diffattack';
%     diff_base_filename = 'peppers_diff';
%
%     analyze_differential_attack(test_img_diff, diff_N, diff_saliency_method, diff_saliency_thresh, ...
%                                 diff_base_params, diff_output_folder, diff_base_filename);
%
%     fprintf('Differential attack analysis example finished. Check folder %s.\n', diff_output_folder);
%     % rmdir(diff_output_folder, 's'); % Clean up
% end
