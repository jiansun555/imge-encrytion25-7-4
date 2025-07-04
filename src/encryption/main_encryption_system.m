function main_encryption_system(image_filename, output_folder)
% main_encryption_system: Main script to run the full encryption and decryption pipeline.
%
% Args:
%   image_filename (str): Name of the image file (e.g., 'peppers.png').
%                         Assumed to be in a readable path or '../images/' folder.
%   output_folder (str): Folder to save output images. Default 'results/'.

    if nargin < 2 || isempty(output_folder)
        output_folder = '../../results'; % Relative to current file's location in src/encryption
    end
    if nargin < 1 || isempty(image_filename)
        % Try a default image if none provided
        if exist('peppers.png', 'file')
            image_filename = 'peppers.png';
        else
            error('Please provide an image filename or make sure peppers.png is available.');
        end
    end

    % Ensure output folder exists
    if ~exist(output_folder, 'dir')
        mkdir(output_folder);
        fprintf('Created output folder: %s\n', output_folder);
    end

    % Construct full image path - assume image might be in shared 'images' folder
    image_base_path = '../../images'; % Relative to current file's location
    full_image_path = fullfile(image_base_path, image_filename);
    if ~exist(full_image_path, 'file')
        % Fallback to current dir if not in ../../images
        full_image_path = image_filename;
        if ~exist(full_image_path, 'file')
            error('Image file not found: %s', image_filename);
        end
    end
    [~, name, ext] = fileparts(image_filename);
    encrypted_image_filename = fullfile(output_folder, [name, '_encrypted', ext]);
    decrypted_image_filename = fullfile(output_folder, [name, '_decrypted', ext]);
    roi_visualization_filename = fullfile(output_folder, [name, '_roi_map', ext]);


    fprintf('--- Starting Full Encryption/Decryption Pipeline for: %s ---\n', full_image_path);

    % --- Parameters ---
    N_psrd_val = 6; % As per paper's default unless specified
    saliency_method_val = 'SR'; % Spectral Residual
    saliency_threshold_val = 'auto';

    % Chaos parameters (consistent across system)
    app_chaos_params.licc_x0 = 0.3;
    app_chaos_params.licc_y0 = 1.5;
    app_chaos_params.licc_z0 = 0.9;
    app_chaos_params.licc_a = 3.9;
    app_chaos_params.licc_b = pi;
    app_chaos_params.licc_c = pi;

    app_chaos_params.logistic_lambda_grouping = 4.0;
    app_chaos_params.logistic_x0_grouping = 0.5;
    app_chaos_params.logistic_lambda_shuffling = 3.95;
    app_chaos_params.logistic_x0_shuffling = 0.55; % For patch order shuffle

    app_chaos_params.T_discard = 1000; % Standard discard for chaotic maps

    % Steganography parameters (used if steganography is fully integrated)
    % app_steg_params.channel_to_embed = 1; % e.g., Red channel
    % app_steg_params.logistic_lambda_steg_key = 3.98;
    % app_steg_params.logistic_x0_steg_key = 0.25;
    % app_steg_params.T_discard_steg = 200;

    original_image = []; % To store the loaded original image

    % --- Run Encryption ---
    try
        fprintf('\nStep 1: ROI Detection\n');
        plain_image_for_enc = imread(full_image_path);
        original_image = plain_image_for_enc; % Keep a copy

        saliency_map_bin = detect_saliency(full_image_path, saliency_method_val, saliency_threshold_val);
        current_ROI_info = psrd(saliency_map_bin, N_psrd_val);

        % Visualize ROIs
        h_roi_fig = figure('Name', 'Detected ROIs', 'Visible', 'off');
        imshow(plain_image_for_enc); hold on;
        num_roi_patches = 0;
        for k_roi=1:length(current_ROI_info)
            if current_ROI_info(k_roi).has_roi && ~isempty(current_ROI_info(k_roi).roi_rect)
                rectangle('Position', current_ROI_info(k_roi).roi_rect, 'EdgeColor', 'r', 'LineWidth', 1);
                num_roi_patches = num_roi_patches + 1;
            end
        end
        title(sprintf('Detected ROIs (%d patches with ROI) on %s', num_roi_patches, strrep(image_filename, '_', '\_')));
        hold off;
        saveas(h_roi_fig, roi_visualization_filename);
        close(h_roi_fig);
        fprintf('ROI detection complete. ROI map saved to %s\n', roi_visualization_filename);

        fprintf('\nStep 2: Pixel Extraction & Grouping\n');
        [seq0, seq1, seq2, idx_seg_shuffled, total_pixels] = ...
            extract_pixels(plain_image_for_enc, current_ROI_info, N_psrd_val, app_chaos_params);

        if total_pixels == 0
            fprintf('No pixels found in ROIs. Skipping encryption.\n');
            encrypted_image_data = plain_image_for_enc;
        else
            fprintf('Total ROI pixels: %d\n', total_pixels);

            fprintf('\nStep 3: Parallel Encryption of Pixel Sequences\n');
            % This is a simplified call. The main function `parallel_encrypt_decrypt`
            % was designed to be more encompassing. Here we call sub-parts.

            num_pix_per_seq = total_pixels;
            [chao0_x_enc, chao0_y_enc, chao0_z_enc] = licc_system(...
                app_chaos_params.licc_x0, app_chaos_params.licc_y0, app_chaos_params.licc_z0, ...
                app_chaos_params.licc_a, app_chaos_params.licc_b, app_chaos_params.licc_c, ...
                num_pix_per_seq, app_chaos_params.T_discard);

            if length(chao0_x_enc) < num_pix_per_seq
                error('LICC failed to generate enough chaos for encryption.');
            end

            cseq0 = encrypt_channel(seq0, chao0_x_enc(1:num_pix_per_seq), 256);
            cseq1 = encrypt_channel(seq1, chao0_y_enc(1:num_pix_per_seq), 256); % Using y stream
            cseq2 = encrypt_channel(seq2, chao0_z_enc(1:num_pix_per_seq), 256); % Using z stream

            fprintf('\nStep 4: Writing Encrypted Pixels to Image\n');
            encrypted_image_data = plain_image_for_enc; % Start with copy

            num_rules_main_enc = floor(total_pixels / 3);
            chaoseq_logi_main_enc = logistic_map(app_chaos_params.logistic_x0_grouping, ...
                                        app_chaos_params.logistic_lambda_grouping, ...
                                        num_rules_main_enc, app_chaos_params.T_discard);
            grouping_rules_main_enc = mod(floor(abs(chaoseq_logi_main_enc) * 6), 6);

            pix_write_cnt_main = 0;
            for k_patch_main = 1:length(idx_seg_shuffled)
                curr_patch_orig_idx_main = idx_seg_shuffled(k_patch_main);
                info_entry_main = current_ROI_info(curr_patch_orig_idx_main); % Assuming ROI_info is already 1 to N*N indexed

                if ~info_entry_main.has_roi || isempty(info_entry_main.roi_rect)
                    continue;
                end
                rect_main = info_entry_main.roi_rect;
                for r_main = rect_main(2) : (rect_main(2)+rect_main(4)-1)
                    for c_main = rect_main(1) : (rect_main(1)+rect_main(3)-1)
                        pix_write_cnt_main = pix_write_cnt_main + 1;

                        val_s0_enc = cseq0(pix_write_cnt_main);
                        val_s1_enc = cseq1(pix_write_cnt_main);
                        val_s2_enc = cseq2(pix_write_cnt_main);

                        rule_main_enc = grouping_rules_main_enc(mod(pix_write_cnt_main-1, num_rules_main_enc)+1);

                        % Inverse of Table 3 logic (as in parallel_encrypt_decrypt's encryption write back)
                        if rule_main_enc == 0     % s0=R, s1=G, s2=B from plain; Write R,G,B to image using these
                            encrypted_image_data(r_main,c_main,1) = val_s0_enc; encrypted_image_data(r_main,c_main,2) = val_s1_enc; encrypted_image_data(r_main,c_main,3) = val_s2_enc;
                        elseif rule_main_enc == 1 % s0=R, s1=B, s2=G
                            encrypted_image_data(r_main,c_main,1) = val_s0_enc; encrypted_image_data(r_main,c_main,2) = val_s2_enc; encrypted_image_data(r_main,c_main,3) = val_s1_enc;
                        elseif rule_main_enc == 2 % s0=G, s1=R, s2=B
                            encrypted_image_data(r_main,c_main,1) = val_s1_enc; encrypted_image_data(r_main,c_main,2) = val_s0_enc; encrypted_image_data(r_main,c_main,3) = val_s2_enc;
                        elseif rule_main_enc == 3 % s0=G, s1=B, s2=R
                            encrypted_image_data(r_main,c_main,1) = val_s2_enc; encrypted_image_data(r_main,c_main,2) = val_s0_enc; encrypted_image_data(r_main,c_main,3) = val_s1_enc;
                        elseif rule_main_enc == 4 % s0=B, s1=R, s2=G
                            encrypted_image_data(r_main,c_main,1) = val_s1_enc; encrypted_image_data(r_main,c_main,2) = val_s2_enc; encrypted_image_data(r_main,c_main,3) = val_s0_enc;
                        elseif rule_main_enc == 5 % s0=B, s1=G, s2=R
                            encrypted_image_data(r_main,c_main,1) = val_s2_enc; encrypted_image_data(r_main,c_main,2) = val_s1_enc; encrypted_image_data(r_main,c_main,3) = val_s0_enc;
                        end
                    end
                end
            end
        end
        imwrite(encrypted_image_data, encrypted_image_filename);
        fprintf('Encryption complete. Encrypted image saved to %s\n', encrypted_image_filename);

    catch ME_enc
        fprintf('ERROR during encryption: %s\n', ME_enc.message);
        disp(ME_enc.stack(1));
        return; % Stop if encryption fails
    end

    % --- Run Decryption ---
    % For decryption, we need the ROI_info and index_seg_shuffled that were used/generated
    % during encryption. In a real system, this would be extracted from steganography.
    % Here, we pass them from the encryption phase.
    if total_pixels == 0 % If no encryption happened
        fprintf('Skipping decryption as no ROIs were encrypted.\n');
        decrypted_image_data = encrypted_image_data; % Which is the original image
    else
        try
            fprintf('\nStep 5: Extracting Ciphered Pixels for Decryption\n');
            % This re-uses logic from parallel_encrypt_decrypt's decryption part
            num_rules_main_dec = floor(total_pixels / 3);
            chaoseq_logi_main_dec_grp = logistic_map(app_chaos_params.logistic_x0_grouping, ...
                                        app_chaos_params.logistic_lambda_grouping, ...
                                        num_rules_main_dec, app_chaos_params.T_discard);
            grouping_rules_main_dec_ext = mod(floor(abs(chaoseq_logi_main_dec_grp) * 6),6);

            cseq0_ext_dec = zeros(1, total_pixels, 'uint8');
            cseq1_ext_dec = zeros(1, total_pixels, 'uint8');
            cseq2_ext_dec = zeros(1, total_pixels, 'uint8');
            pix_ext_cnt_main_dec = 0;

            for k_patch_main_dec = 1:length(idx_seg_shuffled)
                curr_patch_orig_idx_main_dec = idx_seg_shuffled(k_patch_main_dec);
                info_entry_main_dec = current_ROI_info(curr_patch_orig_idx_main_dec);

                if ~info_entry_main_dec.has_roi || isempty(info_entry_main_dec.roi_rect)
                    continue;
                end
                rect_main_dec = info_entry_main_dec.roi_rect;
                for r_main_dec = rect_main_dec(2) : (rect_main_dec(2)+rect_main_dec(4)-1)
                    for c_main_dec = rect_main_dec(1) : (rect_main_dec(1)+rect_main_dec(3)-1)
                        pix_ext_cnt_main_dec = pix_ext_cnt_main_dec + 1;

                        img_R_dec = encrypted_image_data(r_main_dec,c_main_dec,1);
                        img_G_dec = encrypted_image_data(r_main_dec,c_main_dec,2);
                        img_B_dec = encrypted_image_data(r_main_dec,c_main_dec,3);

                        rule_main_dec = grouping_rules_main_dec_ext(mod(pix_ext_cnt_main_dec-1, num_rules_main_dec)+1);

                        if rule_main_dec == 0
                            cseq0_ext_dec(pix_ext_cnt_main_dec)=img_R_dec; cseq1_ext_dec(pix_ext_cnt_main_dec)=img_G_dec; cseq2_ext_dec(pix_ext_cnt_main_dec)=img_B_dec;
                        elseif rule_main_dec == 1
                            cseq0_ext_dec(pix_ext_cnt_main_dec)=img_R_dec; cseq1_ext_dec(pix_ext_cnt_main_dec)=img_B_dec; cseq2_ext_dec(pix_ext_cnt_main_dec)=img_G_dec;
                        elseif rule_main_dec == 2
                            cseq0_ext_dec(pix_ext_cnt_main_dec)=img_G_dec; cseq1_ext_dec(pix_ext_cnt_main_dec)=img_R_dec; cseq2_ext_dec(pix_ext_cnt_main_dec)=img_B_dec;
                        elseif rule_main_dec == 3
                            cseq0_ext_dec(pix_ext_cnt_main_dec)=img_G_dec; cseq1_ext_dec(pix_ext_cnt_main_dec)=img_B_dec; cseq2_ext_dec(pix_ext_cnt_main_dec)=img_R_dec;
                        elseif rule_main_dec == 4
                            cseq0_ext_dec(pix_ext_cnt_main_dec)=img_B_dec; cseq1_ext_dec(pix_ext_cnt_main_dec)=img_R_dec; cseq2_ext_dec(pix_ext_cnt_main_dec)=img_G_dec;
                        elseif rule_main_dec == 5
                            cseq0_ext_dec(pix_ext_cnt_main_dec)=img_B_dec; cseq1_ext_dec(pix_ext_cnt_main_dec)=img_G_dec; cseq2_ext_dec(pix_ext_cnt_main_dec)=img_R_dec;
                        end
                    end
                end
            end

            fprintf('\nStep 6: Parallel Decryption of Sequences\n');
            [chao0_x_dec, chao0_y_dec, chao0_z_dec] = licc_system(...
                app_chaos_params.licc_x0, app_chaos_params.licc_y0, app_chaos_params.licc_z0, ...
                app_chaos_params.licc_a, app_chaos_params.licc_b, app_chaos_params.licc_c, ...
                total_pixels, app_chaos_params.T_discard);

            if length(chao0_x_dec) < total_pixels
                error('LICC failed to generate enough chaos for decryption.');
            end

            dseq0_dec = decrypt_channel(cseq0_ext_dec, chao0_x_dec(1:total_pixels), 256);
            dseq1_dec = decrypt_channel(cseq1_ext_dec, chao0_y_dec(1:total_pixels), 256);
            dseq2_dec = decrypt_channel(cseq2_ext_dec, chao0_z_dec(1:total_pixels), 256);

            fprintf('\nStep 7: Restoring Plain Pixels to Image\n');
            decrypted_image_data = encrypted_image_data; % Start with encrypted image (non-ROI parts are plain)
            pix_restore_cnt_main = 0;
            for k_patch_main_res = 1:length(idx_seg_shuffled)
                curr_patch_orig_idx_main_res = idx_seg_shuffled(k_patch_main_res);
                info_entry_main_res = current_ROI_info(curr_patch_orig_idx_main_res);

                if ~info_entry_main_res.has_roi || isempty(info_entry_main_res.roi_rect)
                    continue;
                end
                rect_main_res = info_entry_main_res.roi_rect;
                for r_main_res = rect_main_res(2) : (rect_main_res(2)+rect_main_res(4)-1)
                    for c_main_res = rect_main_res(1) : (rect_main_res(1)+rect_main_res(3)-1)
                        pix_restore_cnt_main = pix_restore_cnt_main + 1;

                        val_ds0_dec = dseq0_dec(pix_restore_cnt_main);
                        val_ds1_dec = dseq1_dec(pix_restore_cnt_main);
                        val_ds2_dec = dseq2_dec(pix_restore_cnt_main);

                        rule_main_res = grouping_rules_main_dec_ext(mod(pix_restore_cnt_main-1, num_rules_main_dec)+1);
                        % Apply Table 4 logic (mapping {ds0,ds1,ds2} back to {R,G,B})
                        if rule_main_res == 0 % ds0=R, ds1=G, ds2=B (from encryption's perspective)
                            decrypted_image_data(r_main_res,c_main_res,1)=val_ds0_dec; decrypted_image_data(r_main_res,c_main_res,2)=val_ds1_dec; decrypted_image_data(r_main_res,c_main_res,3)=val_ds2_dec;
                        elseif rule_main_res == 1 % ds0=R, ds1=B, ds2=G
                            decrypted_image_data(r_main_res,c_main_res,1)=val_ds0_dec; decrypted_image_data(r_main_res,c_main_res,2)=val_ds2_dec; decrypted_image_data(r_main_res,c_main_res,3)=val_ds1_dec;
                        elseif rule_main_res == 2 % ds0=G, ds1=R, ds2=B
                            decrypted_image_data(r_main_res,c_main_res,1)=val_ds1_dec; decrypted_image_data(r_main_res,c_main_res,2)=val_ds0_dec; decrypted_image_data(r_main_res,c_main_res,3)=val_ds2_dec;
                        elseif rule_main_res == 3 % ds0=G, ds1=B, ds2=R
                            decrypted_image_data(r_main_res,c_main_res,1)=val_ds2_dec; decrypted_image_data(r_main_res,c_main_res,2)=val_ds0_dec; decrypted_image_data(r_main_res,c_main_res,3)=val_ds1_dec;
                        elseif rule_main_res == 4 % ds0=B, ds1=R, ds2=G
                            decrypted_image_data(r_main_res,c_main_res,1)=val_ds1_dec; decrypted_image_data(r_main_res,c_main_res,2)=val_ds2_dec; decrypted_image_data(r_main_res,c_main_res,3)=val_ds0_dec;
                        elseif rule_main_res == 5 % ds0=B, ds1=G, ds2=R
                            decrypted_image_data(r_main_res,c_main_res,1)=val_ds2_dec; decrypted_image_data(r_main_res,c_main_res,2)=val_ds1_dec; decrypted_image_data(r_main_res,c_main_res,3)=val_ds0_dec;
                        end
                    end
                end
            end
        catch ME_dec
            fprintf('ERROR during decryption: %s\n', ME_dec.message);
            disp(ME_dec.stack(1));
            return; % Stop if decryption fails
        end
    end

    imwrite(decrypted_image_data, decrypted_image_filename);
    fprintf('Decryption complete. Decrypted image saved to %s\n', decrypted_image_filename);

    % --- Final Comparison ---
    if ~isempty(original_image) && ~isempty(decrypted_image_data)
        psnr_final = psnr(decrypted_image_data, original_image);
        ssim_final = ssim(decrypted_image_data, original_image);
        fprintf('\n--- Comparison Original vs Final Decrypted ---\n');
        fprintf('PSNR: %.2f dB\n', psnr_final);
        fprintf('SSIM: %.4f\n', ssim_final);

        if psnr_final > 38 && ssim_final > 0.98 % Heuristic thresholds
            fprintf('SUCCESS: Decrypted image is very similar to the original.\n');
        else
            fprintf('NOTE: Decrypted image has noticeable differences from the original.\n');
        end

        h_comp_fig = figure('Name', 'Final Comparison', 'Visible', 'off');
        subplot(1,3,1); imshow(original_image); title('Original');
        subplot(1,3,2); imshow(encrypted_image_data); title('Encrypted ROI');
        subplot(1,3,3); imshow(decrypted_image_data); title(sprintf('Decrypted (PSNR: %.2fdB)', psnr_final));
        comp_fig_filename = fullfile(output_folder, [name, '_comparison', ext]);
        saveas(h_comp_fig, comp_fig_filename);
        close(h_comp_fig);
        fprintf('Comparison figure saved to %s\n', comp_fig_filename);
    end

    fprintf('\n--- Pipeline Finished for: %s ---\n', image_filename);
end

% Helper functions encrypt_channel/decrypt_channel should be defined in
% parallel_encrypt_decrypt.m or be separate files on the path.
% For this main script, they are assumed to be accessible.
% If they are inside parallel_encrypt_decrypt.m, that file needs to be structured
% so these can be called, or they need to be copied/redefined here or made global.
% For now, assuming they are in parallel_encrypt_decrypt.m and that file is on path.
% Or, copy them here:

% --- Helper function for encrypting one channel (Alg. 3) ---
function cseq_j = encrypt_channel(seq_j, chao_j_stream, L)
    len_seq = length(seq_j);
    cseq_j = zeros(1, len_seq, 'uint8');
    if len_seq == 0, return; end

    perm_indices_final = 1:len_seq;
    for i_perm = len_seq:-1:2
        rand_val_for_swap = abs(chao_j_stream(len_seq - i_perm + 2));
        j_perm = mod(floor(rand_val_for_swap * 1e10), i_perm) + 1;
        temp_idx = perm_indices_final(i_perm);
        perm_indices_final(i_perm) = perm_indices_final(j_perm);
        perm_indices_final(j_perm) = temp_idx;
    end

    preVal = mod(floor(abs(chao_j_stream(min(2, len_seq))) * 1e14), L);
    ksele_0 = mod(floor(abs(chao_j_stream(1)) * 1e14), L);

    term1 = ksele_0;
    term2 = mod(double(seq_j(perm_indices_final(1))) + ksele_0, L);
    term3 = preVal;
    cseq_j(1) = bitxor(uint8(term1), bitxor(uint8(term2), uint8(term3)));

    for i = 2:len_seq
        ksele_i = mod(floor(abs(chao_j_stream(i)) * 1e14), L);
        term1_i = ksele_i;
        term2_i = mod(double(seq_j(perm_indices_final(i))) + ksele_i, L);
        term3_i = cseq_j(i-1);
        cseq_j(i) = bitxor(uint8(term1_i), bitxor(uint8(term2_i), uint8(term3_i)));
    end
end

% --- Helper function for decrypting one channel (Inverse of Alg. 3) ---
function dseq_j = decrypt_channel(cseq_j, chao_j_stream, L)
    len_seq = length(cseq_j);
    dseq_j_permuted = zeros(1, len_seq, 'uint8');
    if len_seq == 0, dseq_j = []; return; end % return empty for empty input

    preVal = mod(floor(abs(chao_j_stream(min(2,len_seq))) * 1e14), L);
    ksele_0 = mod(floor(abs(chao_j_stream(1)) * 1e14), L);

    val_xor_0 = bitxor(uint8(cseq_j(1)), bitxor(uint8(preVal), uint8(ksele_0)));
    dseq_j_permuted(1) = mod(double(val_xor_0) - ksele_0 + L, L);

    for i = 2:len_seq
        ksele_i = mod(floor(abs(chao_j_stream(i)) * 1e14), L);
        val_xor_i = bitxor(uint8(cseq_j(i)), bitxor(uint8(cseq_j(i-1)), uint8(ksele_i)));
        dseq_j_permuted(i) = mod(double(val_xor_i) - ksele_i + L, L);
    end

    perm_indices_final = 1:len_seq;
    for i_perm = len_seq:-1:2
        rand_val_for_swap = abs(chao_j_stream(len_seq - i_perm + 2));
        j_perm = mod(floor(rand_val_for_swap * 1e10), i_perm) + 1;
        temp_idx = perm_indices_final(i_perm);
        perm_indices_final(i_perm) = perm_indices_final(j_perm);
        perm_indices_final(j_perm) = temp_idx;
    end

    dseq_j = zeros(1, len_seq, 'uint8');
    for i = 1:len_seq
        dseq_j(perm_indices_final(i)) = dseq_j_permuted(i);
    end
end

% To run this:
% 1. Make sure all dependent .m files (licc_system, logistic_map, detect_saliency, psrd, extract_pixels)
%    are in directories relative to this file as specified by addpath, or on the main Matlab path.
%    E.g., if main_encryption_system.m is in src/encryption/, then chaos_systems should be in src/chaos_systems/
% 2. Call from Matlab command window:
%    main_encryption_system('some_image.png', 'path/to/output_folder');
%    Example: Assuming 'peppers.png' is available and you are in 'src/encryption' directory:
%    main_encryption_system % Uses defaults: peppers.png and results/ folder
%    main_encryption_system('lena.png', '../../my_results')
%
% Note: The file parallel_encrypt_decrypt.m was intended to be a more integrated function.
% This main_encryption_system.m script calls the individual components (extract_pixels,
% then encrypt_channel, then reconstructs image, then extracts for decryption, then decrypt_channel,
% then reconstructs). This is more aligned with a top-level script.
% The reversible_data_hiding part is still a placeholder and not integrated into this main flow.
% If reversible_data_hiding were used, ROI_info and idx_seg_shuffled would be embedded
% into encrypted_image_data, and then extracted from it before decryption.
% This script currently passes these variables directly from encryption to decryption phase.
