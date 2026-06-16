package com.kajhobe.app.ui.feature.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kajhobe.app.data.model.HardcodedServiceCategory
import com.kajhobe.app.ui.theme.KajHobeTheme

private val TopBarHeight = 56.dp
private val TabRowHeight = 48.dp
private val ChipHeight = 36.dp
private val ChipCornerRadius = 10.dp

@Composable
fun HomeTopBar(
    onSearchClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val isDark = KajHobeTheme.isDark
    val bg = if (isDark) Color.Black else Color.White
    val fg = if (isDark) Color.White else Color.Black

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(TopBarHeight)
            .background(bg),
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "KajHobe",
                color = fg,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
            )
            Box(modifier = Modifier.weight(1f))
            IconButton(onClick = onSearchClick) {
                Icon(
                    imageVector = Icons.Filled.Search,
                    contentDescription = "Search",
                    tint = fg,
                )
            }
        }
    }
}

@Composable
fun HomeTabRow(
    onCategoryClick: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val isDark = KajHobeTheme.isDark
    val bg = if (isDark) Color.Black else Color.White
    val listState = rememberLazyListState()

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(TabRowHeight)
            .background(bg),
    ) {
        LazyRow(
            state = listState,
            contentPadding = PaddingValues(horizontal = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxSize(),
        ) {
            item(key = "home") {
                HomeTabChip(
                    label = "Home",
                    selected = true,
                    leadingIcon = Icons.Filled.Home,
                    onClick = { },
                )
            }
            items(HardcodedServiceCategory.categories, key = { it.name }) { category ->
                HomeTabChip(
                    label = category.name,
                    selected = false,
                    leadingIcon = null,
                    onClick = { onCategoryClick(category.name) },
                )
            }
        }
    }
}

@Composable
fun HomeTabChip(
    label: String,
    selected: Boolean,
    leadingIcon: androidx.compose.ui.graphics.vector.ImageVector?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val isDark = KajHobeTheme.isDark
    val selectedBg = if (isDark) Color.White else Color(0xFFE5E5E5)
    val unselectedBg = if (isDark) Color(0xFF1F1F1F) else Color(0xFFF2F2F2)
    val selectedFg = Color.Black
    val unselectedFg = if (isDark) Color.White else Color(0xFF606060)
    val bg = if (selected) selectedBg else unselectedBg
    val fg = if (selected) selectedFg else unselectedFg

    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(ChipCornerRadius),
        color = bg,
        contentColor = fg,
        modifier = modifier.height(ChipHeight),
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            if (leadingIcon != null) {
                Icon(
                    imageVector = leadingIcon,
                    contentDescription = null,
                    tint = fg,
                    modifier = Modifier.size(18.dp),
                )
            }
            Text(
                text = label,
                color = fg,
                fontSize = 14.sp,
                fontWeight = if (selected) FontWeight.Medium else FontWeight.Normal,
            )
        }
    }
}
