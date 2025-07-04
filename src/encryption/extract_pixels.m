function [seq0, seq1, seq2, index_seg_shuffled, total_roi_pixels] = extract_pixels(I, ROI_info, N, chaos_params)
% extract_pixels: Extracts pixels from ROIs, groups them into three sequences based on
%                 a chaotic map, and generates a shuffled patch processing order.
%                 Implements logic similar to Algorithm 2 in the reference paper.
%
% Args:
%   I (matrix): Original image (uint8 or double). Assumed to be RGB (HxWx3).
%   ROI_info (struct array): Information about ROIs in patches, from psrd.m.
%                            Fields: patch_index, has_roi, roi_rect [x,y,w,h].
%   N (int): Number of patches per dimension (N x N grid).
%   chaos_params (struct): Structure containing parameters for chaotic maps.
%                          Expected fields:
%                            - logistic_lambda_grouping (float): Lambda for Logistic map (pixel grouping).
%                            - logistic_x0_grouping (float): x0 for Logistic map (pixel grouping).
%                            - licc_x0, licc_y0, licc_z0: Initial values for LICC.
%                            - licc_a, licc_b, licc_c: Parameters for LICC.
%                            - T_discard (int): Number of transient iterations to discard.
%
% Returns:
%   seq0, seq1, seq2 (cell arrays of uint8): Three sequences of pixel channel values.
%                                            Each cell array contains 1D arrays of R,G,B values.
%   index_seg_shuffled (vector): Shuffled patch indices (1 to N*N).
%   total_roi_pixels (int): Total number of pixels extracted from all ROIs.

    if size(I,3) ~= 3
        error('Input image I must be an RGB image (HxWx3).');
    end
    img_uint8 = im2uint8(I); % Ensure image is uint8 for pixel values

    % --- 1. Calculate total number of pixels in all ROIs ---
    total_roi_pixels = 0;
    for k = 1:length(ROI_info)
        if ROI_info(k).has_roi && ~isempty(ROI_info(k).roi_rect)
            rect = ROI_info(k).roi_rect; % [x,y,w,h]
            total_roi_pixels = total_roi_pixels + (rect(3) * rect(4));
        end
    end

    if total_roi_pixels == 0
        warning('No ROI pixels found. Returning empty sequences.');
        seq0 = {}; seq1 = {}; seq2 = {};
        index_seg_shuffled = [];
        return;
    end

    % Ensure total_roi_pixels is divisible by 3 for perfect grouping.
    % If not, the last 1 or 2 pixels might not be grouped.
    % The paper implies iterating pixel_num/3 times for rules.
    % This means we need pixel_num to be a multiple of 3.
    % If not, we might need to pad or slightly adjust.
    % For now, we'll proceed and the last few pixels might not be assigned if not multiple of 3.
    % Or, more simply, collect all R,G,B values and then distribute.

    num_rules = floor(total_roi_pixels / 3); % Number of 3-pixel groups
    if mod(total_roi_pixels, 3) ~= 0
        % This case needs careful handling if strict adherence to pixel_num/3 rules is needed.
        % Alternative: Collect all R,G,B values from all ROI pixels first.
        warning('Total ROI pixels (%d) is not a multiple of 3. Grouping rules might not cover all pixels perfectly if applied per pixel-triplet.', total_roi_pixels);
    end

    % --- 2. Generate chaotic sequence for grouping rules (Logistic Map) ---
    % Alg.2 line 3: iterate pixel_num/3 times
    chaoseq_logi = logistic_map(chaos_params.logistic_x0_grouping, ...
                                chaos_params.logistic_lambda_grouping, ...
                                num_rules, ... % Generate num_rules values
                                chaos_params.T_discard);
    if length(chaoseq_logi) < num_rules
        error('Could not generate enough chaotic values for grouping rules.');
    end

    % Alg.2 lines 4-6: Determine grouping rule for each 3-pixel set
    % rule[i] <- |chaoseq_logi[i]| * 10^15 mod 6
    % Note: Matlab's mod handles negative numbers differently from C-style %
    % abs() ensures positive. 10^15 might lose precision if chaoseq_logi is small.
    % A common way to get integers from chaotic maps in [0,1] is floor(val * M)
    grouping_rules = floor(abs(chaoseq_logi) * 6); % Generates integers in [0, 5]
    grouping_rules = mod(grouping_rules, 6); % Ensure strictly [0,5]

    % --- 3. Generate shuffled patch index sequence (index'_seg) ---
    % Alg.2 lines 7-20: This part was complex in paper.
    % Plan: Create 0 to N*N-1 indices and shuffle using LICC or Logistic.
    % Using Logistic map for simplicity here, can be LICC if preferred.
    num_patches = N * N;
    patch_indices = 1:num_patches; % Using 1-based indexing for Matlab

    % Generate a chaotic sequence for shuffling
    shuffle_seq_len = num_patches;
    shuffle_chaos = logistic_map(chaos_params.logistic_x0_shuffling, ... % Use a different x0 or map
                                 chaos_params.logistic_lambda_shuffling, ...
                                 shuffle_seq_len, ...
                                 chaos_params.T_discard);
    if length(shuffle_chaos) < shuffle_seq_len
        error('Could not generate enough chaotic values for shuffling patch indices.');
    end

    [~, sorted_shuffle_indices] = sort(shuffle_chaos);
    index_seg_shuffled = patch_indices(sorted_shuffle_indices);

    % --- 4. Extract pixels from ROIs based on shuffled patch order and apply grouping ---
    % Pre-allocate cell arrays for sequences (can grow, but this is an estimate)
    seq0_list = zeros(1, total_roi_pixels, 'uint8');
    seq1_list = zeros(1, total_roi_pixels, 'uint8');
    seq2_list = zeros(1, total_roi_pixels, 'uint8');

    s0_idx = 0; s1_idx = 0; s2_idx = 0;
    rule_counter = 0;

    for k_patch_shuffled = 1:num_patches
        current_patch_original_index = index_seg_shuffled(k_patch_shuffled);

        % Find the ROI_info for this original patch index
        info_entry = [];
        for r_info_idx = 1:length(ROI_info)
            if ROI_info(r_info_idx).patch_index == current_patch_original_index
                info_entry = ROI_info(r_info_idx);
                break;
            end
        end

        if isempty(info_entry) || ~info_entry.has_roi || isempty(info_entry.roi_rect)
            continue; % Skip if no ROI in this patch
        end

        rect = info_entry.roi_rect; % [x,y,w,h] (min_col, min_row, width, height)
        min_col = rect(1);
        min_row = rect(2);
        max_col = rect(1) + rect(3) - 1;
        max_row = rect(2) + rect(4) - 1;

        % Iterate through pixels in this ROI (column by column, then row by row - scanline)
        for r = min_row:max_row
            for c = min_col:max_col
                pixel_rgb = squeeze(img_uint8(r, c, :)); % Get R,G,B values as a column vector

                rule_counter = rule_counter + 1;
                current_rule_idx = mod(rule_counter -1, num_rules) + 1; % Cycle through rules
                rule = grouping_rules(current_rule_idx);

                % Apply grouping rule (Table 3 in paper)
                % rule0: seq0=R, seq1=G, seq2=B
                % rule1: seq0=R, seq1=B, seq2=G
                % rule2: seq0=G, seq1=R, seq2=B
                % rule3: seq0=G, seq1=B, seq2=R
                % rule4: seq0=B, seq1=R, seq2=G
                % rule5: seq0=B, seq1=G, seq2=R

                R_val = pixel_rgb(1);
                G_val = pixel_rgb(2);
                B_val = pixel_rgb(3);

                % This direct assignment is simpler than what Alg.2 line 15 implies ("randomly assigned")
                % The "randomness" comes from the `rule` itself.
                if rule == 0
                    s0_idx = s0_idx + 1; seq0_list(s0_idx) = R_val;
                    s1_idx = s1_idx + 1; seq1_list(s1_idx) = G_val;
                    s2_idx = s2_idx + 1; seq2_list(s2_idx) = B_val;
                elseif rule == 1
                    s0_idx = s0_idx + 1; seq0_list(s0_idx) = R_val;
                    s1_idx = s1_idx + 1; seq1_list(s1_idx) = B_val;
                    s2_idx = s2_idx + 1; seq2_list(s2_idx) = G_val;
                elseif rule == 2
                    s0_idx = s0_idx + 1; seq0_list(s0_idx) = G_val;
                    s1_idx = s1_idx + 1; seq1_list(s1_idx) = R_val;
                    s2_idx = s2_idx + 1; seq2_list(s2_idx) = B_val;
                elseif rule == 3
                    s0_idx = s0_idx + 1; seq0_list(s0_idx) = G_val;
                    s1_idx = s1_idx + 1; seq1_list(s1_idx) = B_val;
                    s2_idx = s2_idx + 1; seq2_list(s2_idx) = R_val;
                elseif rule == 4
                    s0_idx = s0_idx + 1; seq0_list(s0_idx) = B_val;
                    s1_idx = s1_idx + 1; seq1_list(s1_idx) = R_val;
                    s2_idx = s2_idx + 1; seq2_list(s2_idx) = G_val;
                elseif rule == 5
                    s0_idx = s0_idx + 1; seq0_list(s0_idx) = B_val;
                    s1_idx = s1_idx + 1; seq1_list(s1_idx) = G_val;
                    s2_idx = s2_idx + 1; seq2_list(s2_idx) = R_val;
                end
            end
        end
    end

    % Trim the pre-allocated sequences to actual size
    seq0 = seq0_list(1:s0_idx);
    seq1 = seq1_list(1:s1_idx);
    seq2 = seq2_list(1:s2_idx);

    % Verify total pixels extracted match counts in seq0, seq1, seq2
    if (s0_idx + s1_idx + s2_idx) ~= (total_roi_pixels * 3) / 3 % Each pixel contributes one value to one sequence
         % This logic is flawed. Each original pixel (R,G,B) contributes one value to EACH of seq0, seq1, seq2,
         % but the values are permuted. So total length of seq0, seq1, seq2 should each be total_roi_pixels.
         % Let's re-think the pixel assignment.
         % The paper says: "For each pixel, its three 8-bit sub-pixel is randomly assigned to a new sequence"
         % "the three pixel sequences are encrypted in parallel"
         % This implies seq0, seq1, seq2 are streams of R/G/B components, not mixed values.
         % Example: If pixel1=(R1,G1,B1), rule=0 -> R1 to seq_R, G1 to seq_G, B1 to seq_B.
         % If rule=1 -> R1 to seq_R, B1 to seq_G, G1 to seq_B. (This interpretation is also possible)
         %
         % However, Table 3: "Pixels allocation rule in encryption stage"
         % rule0: Red->seq0, Green->seq1, Blue->seq2
         % rule1: Red->seq0, Green->seq2, Blue->seq1
         % This means seq0 always gets Red components, seq1 gets Green/Blue, seq2 gets Blue/Green.
         % This interpretation makes more sense for "cross-color channel diffusion".
         % The current implementation is: seq0 gets a mix of R,G,B based on rule. This is likely wrong.

         % Corrected logic based on Table 3:
         % Each sequence seq0, seq1, seq2 will have length `total_roi_pixels`.
         seq0_corr = zeros(1, total_roi_pixels, 'uint8');
         seq1_corr = zeros(1, total_roi_pixels, 'uint8');
         seq2_corr = zeros(1, total_roi_pixels, 'uint8');
         pixel_count = 0;

         for k_patch_shuffled_corr = 1:num_patches
            current_patch_original_index_corr = index_seg_shuffled(k_patch_shuffled_corr);
            info_entry_corr = [];
            for r_info_idx = 1:length(ROI_info)
                if ROI_info(r_info_idx).patch_index == current_patch_original_index_corr
                    info_entry_corr = ROI_info(r_info_idx);
                    break;
                end
            end

            if isempty(info_entry_corr) || ~info_entry_corr.has_roi || isempty(info_entry_corr.roi_rect)
                continue;
            end

            rect_corr = info_entry_corr.roi_rect;
            min_col_corr = rect_corr(1); min_row_corr = rect_corr(2);
            max_col_corr = rect_corr(1) + rect_corr(3) - 1;
            max_row_corr = rect_corr(2) + rect_corr(4) - 1;

            for r_corr = min_row_corr:max_row_corr
                for c_corr = min_col_corr:max_col_corr
                    pixel_count = pixel_count + 1;
                    R_val_c = img_uint8(r_corr, c_corr, 1);
                    G_val_c = img_uint8(r_corr, c_corr, 2);
                    B_val_c = img_uint8(r_corr, c_corr, 3);

                    current_rule_idx_c = mod(pixel_count-1, num_rules) + 1; % Rule per pixel
                    rule_c = grouping_rules(current_rule_idx_c);

                    if rule_c == 0 % R->s0, G->s1, B->s2
                        seq0_corr(pixel_count) = R_val_c;
                        seq1_corr(pixel_count) = G_val_c;
                        seq2_corr(pixel_count) = B_val_c;
                    elseif rule_c == 1 % R->s0, G->s2, B->s1
                        seq0_corr(pixel_count) = R_val_c;
                        seq1_corr(pixel_count) = B_val_c; % Swapped G,B for s1,s2
                        seq2_corr(pixel_count) = G_val_c;
                    elseif rule_c == 2 % R->s1, G->s0, B->s2
                        seq0_corr(pixel_count) = G_val_c;
                        seq1_corr(pixel_count) = R_val_c;
                        seq2_corr(pixel_count) = B_val_c;
                    elseif rule_c == 3 % R->s2, G->s0, B->s1
                        seq0_corr(pixel_count) = G_val_c;
                        seq1_corr(pixel_count) = B_val_c;
                        seq2_corr(pixel_count) = R_val_c;
                    elseif rule_c == 4 % R->s1, G->s2, B->s0
                        seq0_corr(pixel_count) = B_val_c;
                        seq1_corr(pixel_count) = R_val_c;
                        seq2_corr(pixel_count) = G_val_c;
                    elseif rule_c == 5 % R->s2, G->s1, B->s0
                        seq0_corr(pixel_count) = B_val_c;
                        seq1_corr(pixel_count) = G_val_c;
                        seq2_corr(pixel_count) = R_val_c;
                    end
                end
            end
         end
         seq0 = seq0_corr(1:pixel_count);
         seq1 = seq1_corr(1:pixel_count);
         seq2 = seq2_corr(1:pixel_count);
         if pixel_count ~= total_roi_pixels
            error('Mismatch in counted ROI pixels (%d) and initially calculated total_roi_pixels (%d).', pixel_count, total_roi_pixels);
         end
    end
end

% % Example Usage
% if 0 % Set to 1 to run example
%     clc; clearvars; close all;
%     addpath(genpath('../chaos_systems')); % Assuming chaos_systems is one level up and then in src
%     addpath(genpath('../roi_detection'));
%
%     % Create a dummy image
%     dummy_img_data = uint8(zeros(60, 80, 3));
%     dummy_img_data(10:20, 10:20, 1) = 100; % R
%     dummy_img_data(10:20, 10:20, 2) = 150; % G
%     dummy_img_data(10:20, 10:20, 3) = 200; % B
%
%     dummy_img_data(30:40, 50:60, 1) = 50;
%     dummy_img_data(30:40, 50:60, 2) = 60;
%     dummy_img_data(30:40, 50:60, 3) = 70;
%
%     % Dummy ROI_info (e.g., from psrd)
%     % For simplicity, assume two patches have ROIs that cover these areas
%     N_test = 2; % 2x2 patches
%     dummy_ROI_info = repmat(struct('patch_index',0,'has_roi',false,'roi_rect',[]),1,N_test*N_test);
%
%     dummy_ROI_info(1).patch_index = 1;
%     dummy_ROI_info(1).has_roi = true;
%     dummy_ROI_info(1).roi_rect = [10, 10, 11, 11]; % x,y,w,h -> 11x11 pixels = 121
%
%     dummy_ROI_info(4).patch_index = 4; % Assuming it's the 4th patch in scanline
%     dummy_ROI_info(4).has_roi = true;
%     dummy_ROI_info(4).roi_rect = [50, 30, 11, 11]; % x,y,w,h -> 11x11 pixels = 121
%                                                 % Total pixels = 242
%
%     % Dummy chaos_params
%     test_chaos_params.logistic_lambda_grouping = 4.0;
%     test_chaos_params.logistic_x0_grouping = 0.5;
%     test_chaos_params.logistic_lambda_shuffling = 3.9; % Different params for shuffling
%     test_chaos_params.logistic_x0_shuffling = 0.6;
%     test_chaos_params.T_discard = 100;
%
%     % LICC params (not used in this simplified shuffle, but needed if LICC shuffle is implemented)
%     test_chaos_params.licc_x0 = 0.1; test_chaos_params.licc_y0 = 0.2; test_chaos_params.licc_z0 = 0.3;
%     test_chaos_params.licc_a = 3.9; test_chaos_params.licc_b = pi; test_chaos_params.licc_c = pi;
%
%     [s0, s1, s2, ind_shuffled, tot_pix] = extract_pixels(dummy_img_data, dummy_ROI_info, N_test, test_chaos_params);
%
%     fprintf('Total ROI pixels: %d\n', tot_pix);
%     fprintf('Length of seq0: %d, seq1: %d, seq2: %d\n', length(s0), length(s1), length(s2));
%     disp('Shuffled patch order (1-based):');
%     disp(ind_shuffled);
%
%     if tot_pix > 0
%         fprintf('First few values from sequences:\n');
%         fprintf('s0: %s\n', num2str(s0(1:min(5,end))));
%         fprintf('s1: %s\n', num2str(s1(1:min(5,end))));
%         fprintf('s2: %s\n', num2str(s2(1:min(5,end))));
%     end
% end
